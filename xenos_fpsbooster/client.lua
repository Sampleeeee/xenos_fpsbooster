local Config = {};
Config.UsesEsx = false

local Levels = {};
Levels.ULTRA_LOW    = "ulow"
Levels.LOW          = "low"
Levels.MEDIUM       = "medium"
Levels.RESET        = "reset"

local ESX = nil
local currentLevel = nil

local function Print( message )
    TriggerEvent( "chat:addMessage", {
        args = { "FPS Booster", message }
    } );
end

local function OnChangeLevel( shadows, flashlight, rope, sirens, tracker )
    RopeDrawShadowEnabled( rope or false );

    CascadeShadowsClearShadowSampleType();
    CascadeShadowsSetAircraftMode( false );
    CascadeShadowsEnableEntityTracker( true );
    CascadeShadowsSetDynamicDepthMode( false );
    CascadeShadowsSetEntityTrackerScale( tracker or shadows );
    CascadeShadowsSetDynamicDepthValue( shadows );
    CascadeShadowsSetCascadeBoundsScale( shadows );

    SetFlashLightFadeDistance( flashlight );
    SetLightsCutoffDistanceTweak( flashlight );
    DistantCopCarSirens( sirens or false );
end

local function CheckOnScreen( ent )
    if not IsEntityOnScreen( ent ) then
        SetEntityAlpha( ent, 0 );
        SetEntityAsNoLongerNeeded( ent );
    else
        local alpha = GetEntityAlpha( ent );

        if alpha == 0 then
            SetEntityAlpha( ent, 255 );
        elseif alpha ~= 210 then -- why?
            SetEntityAlpha( ent, 210 ); 
        end
    end
end

local function RemoveIfNotOnScreen()
    for k, v in ipairs( GetGamePool( "CPed" ) ) do
        CheckOnScreen( v );
        SetPedAoBlodRendering( v, false );

        Citizen.Wait( 1 );
    end

    for k, v in ipairs( GetGamePool( "CObject" ) ) do
        CheckOnScreen( v );
        Citizen.Wait( 1 );
    end
end

local function Tick( lodScale, extra, occlusion )
    RemoveIfNotOnScreen();

    if extra then
        SetDisableDecalRenderingThisFrame();
        RemoveParticleFxInRange( GetEntityCoords( PlayerPedId() ), 10.0 );
        SetArtificialLightsState( true );
    end

    if occlusion then
        DisableOcclusionThisFrame();
    end
    
    OverrideLodscaleThisFrame( lodScale );
    Citizen.Wait( 0 );
end

local function Interval( extra )
    ClearAllBrokenGlass();
    ClearAllHelpMessages();
    LeaderboardsReadClearAll();
    ClearBrief();
    ClearGpsFlags();
    ClearPrints();
    ClearSmallPrints();
    ClearReplayStats();
    LeaderboardsClearCacheData();
    ClearFocus();
    ClearHdArea();
    SetWindSpeed( 0.0 );

    if extra then
        local ped = PlayerPedId();

        ClearPedBloodDamage( ped );
        ClearPedWetness( ped );
        ClearPedEnvDirt( ped );
        ResetPedVisibleDamage( ped );
        ClearExtraTimecycleModifier();
        ClearTimecycleModifier();
        ClearOverrideWeather();
        ClearHdArea();
        DisableVehicleDistantlights( false );
        DisableScreenblurFade();
        SetRainLevel( 0.0 );
    end

    Citizen.Wait( extra and 100 or 1000 );
end

local function SimpleThread( level, action )
    Citizen.CreateThread( function() 
        while currentLevel == level do
            action();
        end
    end );
end

local function CreateThreads( level )
    local lodScale = 0.8;

    if level == Levels.ULTRA_LOW then
        lodScale = 0.4;
    elseif level == Levels.LOW then
        lodScale = 0.6;
    end

    local extra = level ~= Levels.MEDIUM;
    local occlusion = level == Levels.ULTRA_LOW;

    SimpleThread( level, function() 
        Tick( lodScale, extra, occlusion );
    end );

    SimpleThread( level, function() 
        Interval( extra );
    end );
end

local function SetLevel( level )
    if level == Levels.RESET then
        OnChangeLevel( 5.0, 10.0, true, true );
    elseif level == Levels.ULTRA_LOW then
        OnChangeLevel( 0.0, 0.0, false, false );
    elseif level == Levels.LOW then
        OnChangeLevel( 0.0, 5.0, false, false );
    elseif level == Levels.MEDIUM then
        OnChangeLevel( 3.0, 3.0, true, false, 5.0 );
    else
        Print( "That is not a valid level. Valid levels: 'ulow', 'low', 'medium', 'reset'." );
        return;
    end

    CreateThreads();
    currentLevel = level;
end

if Config.UsesEsx then
    local function Esx()
        local promise = promise.new();

        Citizen.CreateThread( function()
            while ESX == nil do 
                TriggerEvent( "esx:getSharedObject", function( obj ) 
                    ESX = obj;
                end );

                Citizen.Wait( 10 ) 
            end

            promise:resolve( ESX );
        end );

        return promise;
    end

    local elements = {
        { label = "Ultra Low",  value = Levels.ULTRA_LOW },
        { label = "Low",        value = Levels.LOW },
        { label = "Medium",     value = Levels.MEDIUM },
        { label = "Reset",      value = Levels.RESET }
    }

    local function CloseMenu( _, menu )
        menu.close();
    end

    local function CreateEsxMenu()
        Citizen.Await( Esx() );

        ESX.UI.Menu.CloseAll()
        ESX.UI.Menu.Open( "default", GetCurrentResourceName(), "fps", {
            title       = "FPS Booster",
            align       = "top-left",
            elements    = elements
        }, SetLevel, CloseMenu );
    end

    RegisterCommand( "fps", function( _, args )
        if not args[1] then
            CreateEsxMenu();
            return;
        end

        local level = tostring( args[1] ):lower();
        SetLevel( level );
    end );
    
    TriggerEvent( "chat:addSuggestion", "/fps", "helps players with lower-end computers." );
else
    RegisterCommand( "fps", function( _, args )
        local level = tostring( args[1] or "" ):lower();
        SetLevel( level );
    end );
    
    TriggerEvent( "chat:addSuggestion", "/fps", "helps players with lower-end computers.", {
        { name="level", help="Levels: ulow, low, medium, reset" }
    } );
end
