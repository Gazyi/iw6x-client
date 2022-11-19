// Demolition port for IW6
// IW5 and H1
main()
{
    if ( getdvar( "mapname" ) == "mp_background" )
        return;

    maps\mp\gametypes\_globallogic::init();
    maps\mp\gametypes\_callbacksetup::setupcallbacks();
    maps\mp\gametypes\_globallogic::setupcallbacks();

    if ( isusingmatchrulesdata() )
    {
        level.initializematchrules = ::initializematchrules;
        [[ level.initializematchrules ]]();
        level thread maps\mp\_utility::reinitializematchrulesonmigration();
    }
    else
    {
        maps\mp\_utility::registerroundswitchdvar( level.gametype, 1, 0, 9 );
        maps\mp\_utility::registertimelimitdvar( level.gametype, 3 );
        maps\mp\_utility::registerscorelimitdvar( level.gametype, 0 );
        maps\mp\_utility::registerroundlimitdvar( level.gametype, 3 );
        maps\mp\_utility::registerwinlimitdvar( level.gametype, 2 );
        maps\mp\_utility::registernumlivesdvar( level.gametype, 0 );
        maps\mp\_utility::registerhalftimedvar( level.gametype, 0 );
        maps\mp\_utility::registerwatchdvarfloat( "addtime", 2.5 );

        level.matchrules_damagemultiplier = 0;
        level.matchrules_vampirism = 0;
    }

    maps\mp\_utility::setovertimelimitdvar( 3 );
    level.objectivebased = 1;
    level.teambased = 1;
    level.nobuddyspawns = 1;
    level.onprecachegametype = ::onprecachegametype;
    level.onstartgametype = ::onstartgametype;
    level.getspawnpoint = ::getspawnpoint;
    level.onspawnplayer = ::onspawnplayer;
    level.onplayerkilled = ::onplayerkilled;
    level.ondeadevent = ::ondeadevent;
    level.ontimelimit = ::ontimelimit;
    level.onnormaldeath = ::onnormaldeath;
    level.initgametypeawards = ::initgametypeawards;
    level.gamemodemaydropweapon = maps\mp\_utility::isplayeroutsideofanybombsite;
    //level.allowlatecomers = 0;

    if ( level.matchrules_damagemultiplier || level.matchrules_vampirism )
        level.modifyplayerdamage = maps\mp\gametypes\_damage::gamemodemodifyplayerdamage;

    game["dialog"]["gametype"] = "demolition";

    if ( getdvarint( "g_hardcore" ) )
        game["dialog"]["gametype"] = "hc_" + game["dialog"]["gametype"];
    else if ( getdvarint( "camera_thirdPerson" ) )
        game["dialog"]["gametype"] = "thirdp_" + game["dialog"]["gametype"];
    else if ( getdvarint( "scr_diehard" ) )
        game["dialog"]["gametype"] = "dh_" + game["dialog"]["gametype"];
    else if ( getdvarint( "scr_" + level.gametype + "_promode" ) )
        game["dialog"]["gametype"] += "_pro";

    game["dialog"]["offense_obj"] = "obj_destroy";
    game["dialog"]["defense_obj"] = "obj_defend";
    game["dialog"]["lead_lost"] = "null";
    game["dialog"]["lead_tied"] = "null";
    game["dialog"]["lead_taken"] = "null";

    level.dd = 1;
    level.bombsplanted = 0;
    level.ddbombmodel = [];
    setbombtimerdvar();
    setuibombtimer( "_a", 0 );
    setuibombtimer( "_b", 0 );
}
// IW5 and H1
initializematchrules()
{
    //	set common values
    maps\mp\_utility::setcommonrulesfrommatchrulesdata();
    
    //	set everything else (private match options, default .cfg file values, and what normally is registered in the 'else' below)
    roundSwitch = getmatchrulesdata( "demData", "roundSwitch" );
    setdynamicdvar( "scr_sd_roundswitch", roundSwitch );
    maps\mp\_utility::registerroundswitchdvar( "sd", roundSwitch, 0, 9 );

    setdynamicdvar( "scr_sd_bombtimer", getmatchrulesdata( "demData", "bombTimer" ) );
    setdynamicdvar( "scr_sd_planttime", getmatchrulesdata( "demData", "plantTime" ) );
    setdynamicdvar( "scr_sd_defusetime", getmatchrulesdata( "demData", "defuseTime" ) );

    level.ddtimetoadd = getmatchrulesdata( "demData", "extraTime" );
    SetDynamicDvar( "scr_sd_addtime", level.ddtimetoadd );
    maps\mp\_utility::registerwatchdvarfloat( "addtime", 2.5 );
    setdynamicdvar( "scr_sd_roundlimit", 3 );
    maps\mp\_utility::registerroundlimitdvar( "sd", 0 );
    setdynamicdvar( "scr_sd_winlimit", 2 );
    maps\mp\_utility::registerwinlimitdvar( "sd", 2 );
    setdynamicdvar( "scr_sd_halftime", 0 );
    maps\mp\_utility::registerhalftimedvar( "sd", 0 );

    setdynamicdvar( "scr_sd_promode", 0 );
}
// IW6 SD
onprecachegametype()
{
    game["bomb_dropped_sound"] = "mp_war_objective_lost";
    game["bomb_recovered_sound"] = "mp_war_objective_taken";
}
// H1
onstartgametype()
{
    if ( game["roundsPlayed"] == 2 )
        game["status"] = "overtime";
    
    if ( !isdefined( game["switchedsides"] ) )
        game["switchedsides"] = 0;

    if ( game["switchedsides"] )
    {
        oldAttackers = game["attackers"];
        oldDefenders = game["defenders"];
        game["attackers"] = oldDefenders;
        game["defenders"] = oldAttackers;
    }

    level.useStartSpawns = true;
    setclientnamemode( "manual_change" );

    level._effect["bomb_explosion"] = loadfx( "fx/explosions/tanker_explosion" );
    level._effect["vehicle_explosion"] = loadfx( "fx/explosions/small_vehicle_explosion_new" );
    level._effect["building_explosion"] = loadfx( "fx/explosions/building_explosion_gulag" );

    maps\mp\_utility::setobjectivetext( game["attackers"], &"OBJECTIVES_DD_ATTACKER" );
    maps\mp\_utility::setobjectivetext( game["defenders"], &"OBJECTIVES_DD_DEFENDER" );

    if ( level.splitscreen )
    {
        maps\mp\_utility::setobjectivescoretext( game["attackers"], &"OBJECTIVES_DD_ATTACKER" );
        maps\mp\_utility::setobjectivescoretext( game["defenders"], &"OBJECTIVES_DD_DEFENDER" );
    }
    else
    {
        maps\mp\_utility::setobjectivescoretext( game["attackers"], &"OBJECTIVES_DD_ATTACKER_SCORE" );
        maps\mp\_utility::setobjectivescoretext( game["defenders"], &"OBJECTIVES_DD_DEFENDER_SCORE" );
    }

    maps\mp\_utility::setobjectivehinttext( game["attackers"], &"OBJECTIVES_DD_ATTACKER_HINT" );
    maps\mp\_utility::setobjectivehinttext( game["defenders"], &"OBJECTIVES_DD_DEFENDER_HINT" );

    initspawns();
    thread updategametypedvars();
    thread waittoprocess();

    winlimit = maps\mp\_utility::getwatcheddvar( "winlimit" );

    //allowed[0] = "sd";
    allowed[0] = "dd";
    allowed[1] = "bombzone";
    vallowed[2] = "blocker";
    maps\mp\gametypes\_gameobjects::main( allowed );

    thread bombs();
}
// IW6 SR
initspawns()
{
	level.spawnMins = ( 0, 0, 0 );
	level.spawnMaxs = ( 0, 0, 0 );	
	
	maps\mp\gametypes\_spawnlogic::addStartSpawnPoints( "mp_sd_spawn_attacker" );
	maps\mp\gametypes\_spawnlogic::addStartSpawnPoints( "mp_sd_spawn_defender" );

	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "attacker", "mp_tdm_spawn" );
	maps\mp\gametypes\_spawnlogic::addSpawnPoints( "defender", "mp_tdm_spawn" );

	level.mapCenter = maps\mp\gametypes\_spawnlogic::findBoxCenter( level.spawnMins, level.spawnMaxs );
	setMapCenter( level.mapCenter );
}
// H1
waittoprocess()
{
    level endon( "game_end" );

    for (;;)
    {
        if ( level.ingraceperiod == 0 )
            break;

        wait 0.05;
    }

    level.usestartspawns = 0;
}
// IW6 SR
getspawnpoint()
{
    spawnteam = "defender";

    if( self.pers["team"] == game["attackers"] )
	{
		spawnteam = "attacker";
	}

    if ( maps\mp\gametypes\_spawnlogic::shouldUseTeamStartSpawn() )
	{
		spawnPoints = maps\mp\gametypes\_spawnlogic::getSpawnpointArray( "mp_sd_spawn_" + spawnteam );
		spawnPoint 	= maps\mp\gametypes\_spawnlogic::getSpawnpoint_startSpawn( spawnPoints );
	}
	else
	{
		spawnPoints = maps\mp\gametypes\_spawnlogic::getTeamSpawnPoints( spawnteam );
		spawnPoint 	= maps\mp\gametypes\_spawnscoring::getSpawnpoint_SearchAndRescue( spawnPoints );
	}
	
	return spawnPoint;
}
// H1
onspawnplayer()
{
    if ( self.pers["team"] == game["attackers"] )
    {
        self.isplanting = 0;
        self.isdefusing = 0;
        self.isbombcarrier = 1;
    }
    else
    {
        self.isplanting = 0;
        self.isdefusing = 0;
        self.isbombcarrier = 0;
    }

    self setclientomnvar( "ui_carrying_bomb", self.isbombcarrier );

    maps\mp\_utility::setextrascore0( 0 );
    if ( isdefined( self.pers["plants"] ) )
        maps\mp\_utility::setextrascore0( self.pers["plants"] );

    setextrascore1( 0 );
    if ( isdefined( self.pers["defuses"] ) )
        setextrascore1( self.pers["defuses"] );

    level notify( "spawned_player" );
}
// IW6
onPlayerKilled(eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration, killId)
{
	self SetClientOmnvar( "ui_bomb_planting_defusing", 0 );
    self SetClientOmnvar( "ui_carrying_bomb", false );
    self.ui_bomb_planting_defusing = undefined;
}
// same as IW5 and H1
dd_endGame( winningTeam, endReasonText )
{
	foreach( player in level.players )
	{
		// make sure we reset the planting/defusing hud
		player SetClientOmnvar( "ui_bomb_planting_defusing", 0 );
        player SetClientOmnvar( "ui_carrying_bomb", false );
	}
    
    if ( winningTeam == "tie" )
		level.finalKillCam_winner = "none";
	else
		level.finalKillCam_winner = winningTeam;
	
	thread maps\mp\gametypes\_gamelogic::endGame( winningTeam, endReasonText );
}
// Same as IW4/IW5/H1
ondeadevent( team )
{
    if ( level.bombexploded || level.bombdefused )
        return;

    if ( team == "all" )
    {
        if ( level.bombPlanted )
            dd_endGame( game["attackers"], game[ "end_reason" ][game["defenders"]+"_eliminated"] );
        else
			dd_endGame( game["defenders"], game[ "end_reason" ][game["attackers"]+"_eliminated"] );
    }
    else if ( team == game["attackers"] )
	{
		if ( level.bombPlanted )
			return;

		level thread dd_endGame( game["defenders"], game[ "end_reason" ][game["attackers"]+"_eliminated"] );
	}
    else if ( team == game["defenders"] )
	{
		level thread dd_endGame( game["attackers"], game[ "end_reason" ][game["defenders"]+"_eliminated"] );
	}
}
// IW4 and IW5
onnormaldeath( victim, attacker, lifeId )
{
    score = maps\mp\gametypes\_rank::getscoreinfovalue( "kill" );
    team = victim.team;

    if ( game["state"] == "postgame" && ( victim.team == game["defenders"] || !level.bombplanted ) )
        attacker.finalkill = true;

    if ( victim.isplanting )
    {
        thread maps\mp\_matchdata::logkillevent( lifeId, "planting" );
        attacker maps\mp\_utility::incpersstat( "defends", 1 );
        attacker maps\mp\gametypes\_persistence::statsetchild( "round", "defends", attacker.pers["defends"] );
    }
    else if ( victim.isdefusing )
    {
        thread maps\mp\_matchdata::logkillevent( lifeId, "defusing" );
        attacker maps\mp\_utility::incpersstat( "defends", 1 );
        attacker maps\mp\gametypes\_persistence::statsetchild( "round", "defends", attacker.pers["defends"] );
    }
}
// IW4
ontimelimit()
{
    dd_endGame( game["defenders"], game[ "end_reason" ]["time_limit_reached"] );
}
// IW4 and IW5
updategametypedvars()
{
    level.planttime = maps\mp\_utility::dvarfloatvalue( "planttime", 5, 0, 20 );
    level.defusetime = maps\mp\_utility::dvarfloatvalue( "defusetime", 5, 0, 20 );
    level.bombtimer = maps\mp\_utility::dvarfloatvalue( "bombtimer", 45, 1, 300 );
    level.ddtimetoadd = maps\mp\_utility::dvarFloatValue( "addtime", 2, 0, 5 );   //how much time is added to the match when a target is destroyed

    println("Plant Time: " + level.planttime);
    println("Defuse Time: " + level.defusetime);
    println("Bomb Time: " + level.bombtimer);
    println("Bonus Time: " + level.ddtimetoadd);
}
// IW5 and H1
verifyBombzones( bombZones )
{
    missing = "";
	if ( bombZones.size != 3 )
	{
		foundA = false;
		foundB = false;
		foundC = false;
		foreach ( bombZone in BombZones )
		{
			if ( isSubStr( toLower( bombZone.script_label ), "a" ) )
            {
				foundA = true;
                continue;
            }
			else if ( isSubStr( toLower( bombZone.script_label ), "b" ) )
            {
				foundB = true;
                continue;
            }
			else if ( isSubStr( toLower( bombZone.script_label ), "c" ) )
				foundC = true;		
		}
		if ( !foundA )
			missing += " A ";
		if ( !foundB )
			missing += " B ";
		if ( !foundC )
			missing += " C ";
	}

	if ( missing != "" )
    {
		println( "Bombzones:" + missing + "missing." );
    }
    return bombZones;
}
// H1
bombs()
{
    waittillframeend;
    level.bombplanted = 0;
    level.bombdefused = 0;
    level.bombexploded = 0;

    level.bombzones = [];
    bombzones = getentarray( "bombzone", "targetname" );
    bombzones = verifyBombzones( bombzones );

    for ( index = 0; index < bombzones.size; index++ )
    {
        //	get the trigger and visuals for the bombsite
        trigger = bombZones[index];
        
        // H1 createbombzoneobject
        visuals = getEntArray( bombZones[index].target, "targetname" );
        //	create defender bombsites
        bombzone = maps\mp\gametypes\_gameobjects::createUseObject( game["defenders"], trigger, visuals, (0,0,64) );
        bombzone.label = bombzone maps\mp\gametypes\_gameobjects::getlabel();
        bombzone resetbombzone( level.ddbomb, "enemy", "any", 1 );
        bombzone.id = "bomb_zone";

        for ( i = 0; i < visuals.size; i++ )
		{
            if ( isDefined( visuals[i].script_exploder ) )
            {
                bombzone.exploderindex = visuals[i].script_exploder;
                visuals[i] thread setupkillcament( bombzone );
                break;
            }
        }
        // end of H1 createbombzoneobject

        bombzone.onbeginuse = ::onbeginuse;
        bombzone.onenduse = ::onenduse;
        bombzone.onuse = ::onuseobject;
        bombzone.oncantuse = ::oncantuse;
        level.bombzones[level.bombzones.size] = bombzone;
    }
}
// IW6
setupkillcament( var_0 )
{
    var_1 = spawn( "script_origin", self.origin );
    var_1.angles = self.angles;
    var_1 rotateyaw( -45, 0.05 );
    wait 0.05;
    var_2 = undefined;

    if ( isdefined( level.srkillcamoverrideposition ) && isdefined( level.srkillcamoverrideposition[var_0.label] ) )
        var_2 = level.srkillcamoverrideposition[var_0.label];
    else
    {
        var_3 = self.origin + ( 0.0, 0.0, 5.0 );
        var_4 = self.origin + anglestoforward( var_1.angles ) * 100 + ( 0.0, 0.0, 128.0 );
        var_5 = bullettrace( var_3, var_4, 0, self );
        var_2 = var_5["position"];
    }

    self.killcament = spawn( "script_model", var_2 );
    self.killcament setscriptmoverkillcam( "explosive" );
    var_0.killcamentnum = self.killcament getentitynumber();
    var_1 delete();
}
// H1
onuseobject( player )
{
    playerTeam = player.pers["team"];
    enemyTeam = level.otherteam[playerTeam];

    if ( !self maps\mp\gametypes\_gameobjects::isfriendlyteam( player.pers["team"] ) )
    {
        player onplayerplantbomb( 0, playerTeam, enemyTeam );
        level thread bombplanted( self, player );
    }
    else
    {
        player onplayerdefusebomb( "defuse", playerTeam, enemyTeam );
        level thread bombdefused( self );
    }
}
// H1
setupzonefordefusing( var_0 )
{
    var_1 = "waypoint_defuse";
    var_2 = "waypoint_defend";

    if ( var_0 )
    {
        var_1 += self.label;
        var_2 += self.label;
    }

    maps\mp\gametypes\_gameobjects::allowuse( "friendly" );
    maps\mp\gametypes\_gameobjects::setusetime( level.defusetime );
    maps\mp\gametypes\_gameobjects::setusehinttext( &"PLATFORM_HOLD_TO_DEFUSE_EXPLOSIVES" );
    maps\mp\gametypes\_gameobjects::setkeyobject( undefined );
    maps\mp\gametypes\_gameobjects::set2dicon( "friendly", var_1 );
    maps\mp\gametypes\_gameobjects::set3dicon( "friendly", var_1 );
    maps\mp\gametypes\_gameobjects::set2dicon( "enemy", var_2 );
    maps\mp\gametypes\_gameobjects::set3dicon( "enemy", var_2 );
    maps\mp\gametypes\_gameobjects::setvisibleteam( "any" );
    self.useweapon = "briefcase_bomb_defuse_mp";
    self.cantuseweapon = "briefcase_bomb_mp";
}
// H1
onbeginuse( player )
{
    if ( self maps\mp\gametypes\_gameobjects::isfriendlyteam( player.pers["team"] ) )
    {
        closestBomb = player getclosestbombmodel();
        // H1 onbegindefusebomb
        player maps\mp\_utility::notify_enemy_bots_bomb_used( "defuse" );
        player thread startnpcbombusesound( "briefcase_bomb_defuse_mp", "weap_suitcase_defuse_button" );

        player.isdefusing = true;

        if ( isdefined(closestBomb))
        {
            closestBomb hide();
            self.hiddenmodel = closestBomb;
        }
    }
    else
    {
        // H1 onbeginplantbomb
        player maps\mp\_utility::notify_enemy_bots_bomb_used( "plant" );
        player thread startnpcbombusesound( "briefcase_bomb_mp", "weap_suitcase_raise_button" );

        player.isplanting = true;
        player.bombplantweapon = self.useweapon;
    }
}
// H1
getclosestbombmodel()
{
    bestDistance = 9000000;
    closestBomb = undefined;

    if ( isdefined( level.ddbombmodel ) )
    {
        foreach ( bomb in level.ddbombmodel )
        {
            if ( !isdefined( bomb ) )
                continue;

            dist = distancesquared( self.origin, bomb.origin );

            if ( dist < bestDistance )
            {
                bestDistance = dist;
                closestBomb = bomb;
            }
        }
    }

    return closestBomb;
}
// IW5
onenduse( team, player, result)
{
    if ( !isDefined( player ) )
        return;
    
    if ( isAlive( player ) )
    {
        player.isDefusing = false;
        player.isPlanting = false;
    }
	if( IsPlayer( player ) )
	{
		player SetClientOmnvar( "ui_bomb_planting_defusing", 0 );
		player.ui_bomb_planting_defusing = undefined;	
	}
    if ( player.isDefusing )
    {
        if ( isDefined( player.defusing ) && !result )
        {
            player.defusing show();
        }
    }
}
// Same as IW4/IW5/H1
oncantuse( player )
{
    player iprintlnbold( &"MP_BOMBSITE_IN_USE" );
}

onreset()
{
}

destructionverify( bombzones )
{
    foreach( bombzone in bombzones )
    {
        println( "Bombsite " + bombzone.script_label + " VisibleTeam: "  + bombzone.visibleTeam);
    }
}

// H1 without overtime
bombplanted( destroyedObj, player )
{
    destroyedObj endon( "defused" );
    level.bombsplanted += 1;
    playerTeam = player.team;
    setbombtimerdvar();
    level.bombplanted = 1;

    if ( destroyedObj.label == "_a" )
        level.aplanted = 1;
    else
        level.bplanted = 1;

    dropbombmodel( player, destroyedObj.label );

    destroyedObj setupzonefordefusing();
    destroyedObj onbombplanted( level.ddbombmodel[destroyedObj.label].origin + ( 0.0, 0.0, 1.0 ) );
    destroyedObj bombtimerwait( destroyedObj ); //waits for bomb to explode!

    println("Explosion!");

    destroyedObj.tickingobject maps\mp\gametypes\_gamelogic::stopTickingSound();
    level.bombsplanted -= 1;

    if ( destroyedObj.label == "_a" )
        level.aplanted = 0;
    else
        level.bplanted = 0;

    destructionverify(level.bombzones);

    destroyedObj restarttimer();
    destroyedObj setbombtimerdvar();
    setuibombtimer( destroyedObj.label, 0 );

    if ( level.gameended )
        return;
    
    level notify( "bomb_exploded" + destroyedObj.label );
    level.bombexploded += 1;

    explosionOrigin = destroyedObj.curorigin;
    level.ddbombmodel[destroyedObj.label] delete();

    destroyedObj onbombexploded( explosionOrigin, 200, player );
    destroyedObj maps\mp\gametypes\_gameobjects::disableobject();

    bonusTime = false;

    if ( level.bombexploded < 2 && level.ddtimetoadd > 0 )
    {
        timelimit = maps\mp\_utility::gettimelimit();

        if (timelimit > 0)
        {
            //maps\mp\_utility::setoverridewatchdvar( "timelimit", maps\mp\_utility::getwatcheddvar( "timelimit" ) + level.ddtimetoadd );

            foreach ( splashPlayer in level.players )
                splashPlayer thread maps\mp\gametypes\_hud_message::SplashNotify( "time_added" );

            bonusTime = true;
        }
    }

    if ( level.bombexploded > 1 )
    {
        setgameendtime( 0 );
        level.timelimitoverride = 1;
    }

    wait 2;

    if ( level.bombexploded > 1 )
        dd_endgame( playerTeam, game["end_reason"]["target_destroyed"] );
    else if (bonusTime)
        level thread maps\mp\_utility::teamplayercardsplash( "callout_time_added", player );
}
// Same as IW4/IW5/H1
setbombtimerdvar()
{
    println( "BOMBS PLANTED: " + level.bombsPlanted );
    
    if ( level.bombsplanted == 1 )
        setomnvar( "ui_bomb_timer", 2 );
    else if ( level.bombsplanted == 2 )
        setomnvar( "ui_bomb_timer", 3 );
    else
        setomnvar( "ui_bomb_timer", 0 );
}
// Same as IW4/IW5/H1
dropbombmodel( player, site )
{
    trace = bullettrace( player.origin + ( 0.0, 0.0, 20.0 ), player.origin - ( 0.0, 0.0, 2000.0 ), false, player );
    tempAngle = randomfloat( 360 );
    forward = ( cos( tempAngle ), sin( tempAngle ), 0 );
    forward = vectornormalize( forward - trace["normal"] * vectordot( forward, trace["normal"] ) );
    dropAngles = vectortoangles( forward );
    level.ddbombmodel[site] = spawn( "script_model", trace["position"] );
    level.ddbombmodel[site].angles = dropAngles;
    level.ddbombmodel[site] setmodel( "weapon_briefcase_bomb_iw6" );
}
// Same as IW4/IW5/H1
restarttimer()
{
    if ( level.bombsplanted <= 0 )
    {
        maps\mp\gametypes\_gamelogic::resumetimer();
        level.timepaused = gettime() - level.timepausestart;
        level.timelimitoverride = false;
    }
}
// H1
bombtimerwait( siteLoc )
{
    level endon( "game_ended" );
    level endon( "bomb_defused" + siteLoc.label);

    siteLoc.waittime = level.bombtimer;
    level thread update_ui_timers( siteLoc );

    while (siteLoc.waittime >= 0)
    {
        siteLoc.waittime -= 1;

        if ( siteLoc.waittime >= 0 )
            wait 1;
        //println("Timer: " + siteLoc.waittime);
        maps\mp\gametypes\_hostmigration::waittillhostmigrationdone();
    }

    //println("Timer expired!");
    return;
}
// H1
update_ui_timers( site )
{
    level endon( "game_ended" );
    level endon( "disconnect" );
    level endon( "bomb_defused" + site.label );
    level endon( "bomb_exploded" + site.label );
    var_1 = site.waittime * 1000 + gettime();
    setuibombtimer( site.label, var_1 );
    level waittill( "host_migration_begin" );
    var_2 = maps\mp\gametypes\_hostmigration::waittillhostmigrationdone();

    if ( var_2 > 0 )
        setuibombtimer( site.label, var_1 + var_2 );
}
// H1
bombdefused( siteDefused )
{
    siteDefused.bombplantedon = false;
    siteDefused notify( "defused" );
    siteDefused.tickingobject maps\mp\gametypes\_gamelogic::stopTickingSound();
    level.bombsplanted -= 1;
    siteDefused restarttimer();
    setbombtimerdvar();
    setuibombtimer( siteDefused.label, 0 );
    level notify( "bomb_defused" + siteDefused.label );
    level.ddbombmodel[siteDefused.label] delete();
    siteDefused resetBombZone( level.ddbomb, "enemy", "any", 1 );
}
// Same as IW4 and IW5
initgametypeawards()
{
    maps\mp\_awards::initstataward( "targetsdestroyed", 0, maps\mp\_awards::highestwins );
    maps\mp\_awards::initstataward( "bombsplanted", 0, maps\mp\_awards::highestwins );
    maps\mp\_awards::initstataward( "bombsdefused", 0, maps\mp\_awards::highestwins );
    maps\mp\_awards::initstataward( "bombcarrierkills", 0, maps\mp\_awards::highestwins );
    maps\mp\_awards::initstataward( "bombscarried", 0, maps\mp\_awards::highestwins );
    maps\mp\_awards::initstataward( "killsasbombcarrier", 0, maps\mp\_awards::highestwins );
}
// H1
setuibombtimer( site, value )
{
    if ( site == "_a" )
        setomnvar( "ui_bomb_timer_endtime", int(value) );
    else
        setomnvar( "ui_bomb_timer_endtime_2", int(value) );
}
// IW6
startnpcbombusesound( var_0, var_1 )
{
    self endon( "death" );
    self endon( "stopNpcBombSound" );

    if ( maps\mp\_utility::isanymlgmatch() )
        return;

    var_2 = "";

    while ( var_2 != var_0 )
        self waittill( "weapon_change", var_2 );

    self playsoundtoteam( var_1, self.team, self );
    var_3 = maps\mp\_utility::getotherteam( self.team );
    self playsoundtoteam( var_1, var_3 );
    self waittill( "weapon_change" );
    self notify( "stopNpcBombSound" );
}
// H1
onplayerplantbomb( removeBomb, playerTeam, enemyTeam )
{
    self notify( "bomb_planted" );

    // H1 bombplantevent
    maps\mp\_utility::incplayerstat( "bombsplanted", 1 );
    maps\mp\_utility::incpersstat( "plants", 1 );
    maps\mp\gametypes\_persistence::statsetchild( "round", "plants", self.pers["plants"] );

    maps\mp\_utility::setextrascore0( self.pers["plants"] );
    level thread maps\mp\_utility::teamplayercardsplash( "callout_bombplanted", self );
    
    thread maps\mp\gametypes\_hud_message::SplashNotify( "plant", maps\mp\gametypes\_rank::getScoreInfoValue( "plant" ) );
    // H1 awardgameevent
    thread maps\mp\gametypes\_rank::xpEventPopup( "plant" );
    thread maps\mp\gametypes\_rank::giveRankXP( "plant" );
    maps\mp\gametypes\_gamescore::givePlayerScore( "plant", self );
    // end of H1 awardgameevent

    thread maps\mp\_matchdata::loggameevent( "plant", self.origin );
    // end of H1 bombplantevent

    self.bombplantedtime = gettime();

    if ( isplayer( self ) && removeBomb )
    {
        self.isbombcarrier = 0;
        self setclientomnvar( "ui_carrying_bomb", 0 );
    }

    self playsound( "mp_bomb_plant" );
    maps\mp\_utility::leaderdialog( "bomb_planted" );
    level.bombowner = self;
}
// H1
onplayerdefusebomb( event, playerTeam, enemyTeam ) // self == player
{
    self notify( "bomb_defused" );

    // H1 bombdefuseevent
    maps\mp\_utility::incplayerstat( "bombsdefused", 1 );
    maps\mp\_utility::incpersstat( "defuses", 1 );
    maps\mp\gametypes\_persistence::statsetchild( "round", "defuses", self.pers["defuses"] );

    setextrascore1( self.pers["defuses"] );
    level thread maps\mp\_utility::teamplayercardsplash( "callout_bombdefused", self );
    
	if ( isDefined( level.bombOwner ) && ( level.bombOwner.bombPlantedTime + 3000 + (level.defuseTime*1000) ) > getTime() && maps\mp\_utility::isreallyalive( level.bombOwner ) )
		thread maps\mp\gametypes\_hud_message::SplashNotify( "ninja_defuse", ( maps\mp\gametypes\_rank::getScoreInfoValue( "defuse" ) ) );
	else
		thread maps\mp\gametypes\_hud_message::SplashNotify( "defuse", maps\mp\gametypes\_rank::getScoreInfoValue( "defuse" ) );
    
    // H1 awardgameevent
    thread maps\mp\gametypes\_rank::xpEventPopup( "defuse" );
    thread maps\mp\gametypes\_rank::giveRankXP( "defuse" );
    maps\mp\gametypes\_gamescore::givePlayerScore( "defuse", self );
    // end of H1 awardgameevent

    thread maps\mp\_matchdata::loggameevent( "defuse", self.origin );
    // end of H1 bombdefuseevent

    maps\mp\_utility::leaderdialog( "bomb_defused" );
    level.bombowner = undefined;
}
// H1 Utility
setextrascore1( newValue )
{
    self.extrascore1 = newValue;
    maps\mp\_utility::setpersstat( "extrascore1", newValue );
}
// H1
resetbombzone( var_0, var_1, var_2, var_3 )
{
    maps\mp\gametypes\_gameobjects::allowuse( var_1 );
    maps\mp\gametypes\_gameobjects::setvisibleteam( var_2 );
    maps\mp\gametypes\_gameobjects::setusetime( level.planttime );
    maps\mp\gametypes\_gameobjects::setusehinttext( &"PLATFORM_HOLD_TO_PLANT_EXPLOSIVES" );
    maps\mp\gametypes\_gameobjects::setkeyobject( var_0 );
    var_4 = "waypoint_defend";
    var_5 = "waypoint_target";

    if ( var_1 == "any" )
    {
        var_4 = "waypoint_target";
        var_5 = "waypoint_target";
    }

    if ( var_3 )
    {
        var_4 += self.label;
        var_5 += self.label;
    }

    maps\mp\gametypes\_gameobjects::set2dicon( "friendly", var_4 );
    maps\mp\gametypes\_gameobjects::set3dicon( "friendly", var_4 );
    maps\mp\gametypes\_gameobjects::set2dicon( "enemy", var_5 );
    maps\mp\gametypes\_gameobjects::set3dicon( "enemy", var_5 );
    self.useweapon = "briefcase_bomb_mp";
    self.cantuseweapon = "briefcase_bomb_defuse_mp";
    self.bombplantedon = 0;
}
// H1
onbombplanted( var_0 )
{
    level notify( "bomb_planted", self );
    self.bombplantedon = 1;
    level.timelimitoverride = 1;
    maps\mp\gametypes\_gamelogic::pausetimer();
    level.timepausestart = gettime();

    self.tickingobject = self.visuals[0];
    self.tickingobject thread playtickingsound();
}
// H1
onbombexploded( explosionOrigin, radius, player )
{
    if ( isdefined( player ) )
    {
        self.visuals[0] radiusdamage( explosionOrigin, 512, radius, 20, player, "MOD_EXPLOSIVE", "bomb_site_mp" );
        // H1 bombdetonateevent
        player maps\mp\_utility::incplayerstat( "targetsdestroyed", 1 );
        player maps\mp\_utility::incpersstat( "destructions", 1 );
        maps\mp\gametypes\_persistence::statsetchild( "round", "destructions", player.pers["destructions"] );
        //level thread maps\mp\_utility::teamplayercardsplash( "callout_destroyed_objective", player );
        // H1 awardgameevent
        //player thread maps\mp\gametypes\_rank::xpEventPopup( "destroy" );
        //player thread maps\mp\gametypes\_rank::giveRankXP( "destroy" );
        //maps\mp\gametypes\_gamescore::givePlayerScore( "destroy", player );
        // end of H1 awardgameevent
        // end of H1 bombdetonateevent
    }
    else
        self.visuals[0] radiusdamage( explosionOrigin, 512, radius, 20, undefined, "MOD_EXPLOSIVE", "bomb_site_mp" );

    rot = randomfloat( 360 );
    if ( isDefined( self.trigger.effect ) )
		effect = self.trigger.effect;
	else
		effect = "bomb_explosion";	

    explosionPos = explosionOrigin + (0,0,50);
    explosionEffect = spawnFx( level._effect[effect], explosionPos, (0,0,1), (cos(rot),sin(rot),0) );
    triggerFx( explosionEffect );
    PhysicsExplosionSphere( explosionPos, 200, 100, 3 );
    playrumbleonposition( "grenade_rumble", explosionOrigin );
    earthquake( 0.75, 2.0, explosionOrigin, 2000 );

    thread maps\mp\_utility::playsoundinspace( "exp_suitcase_bomb_main", explosionOrigin );

    if ( isdefined( self.exploderindex ) )
        common_scripts\utility::exploder( self.exploderindex );
}

playtickingsound()
{
    self endon( "death" );
    self endon( "stop_ticking" );
    level endon( "game_ended" );
    var_0 = level.bombtimer;

    for (;;)
    {
        self playsound( "ui_mp_suitcasebomb_timer" );

        if ( var_0 > 10 )
        {
            var_0 -= 1;
            wait 1;
        }
        else if ( var_0 > 4 )
        {
            var_0 -= 0.5;
            wait 0.5;
        }
        else if ( var_0 > 1 )
        {
            var_0 -= 0.4;
            wait 0.4;
        }
        else
        {
            var_0 -= 0.3;
            wait 0.3;
        }

        maps\mp\gametypes\_hostmigration::waittillhostmigrationdone();
    }
}