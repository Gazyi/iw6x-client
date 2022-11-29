// IW6 GSC SOURCE
// Decompiled by https://github.com/xensik/gsc-tool

main()
{
    _id_710C();
    bot_dd_start(); // bot_sd_start();
}

_id_710C() //setup_callbacks();
{
    level.bot_funcs["crate_can_use"] = ::_id_90A1;
    level.bot_funcs["gametype_think"] = ::bot_dd_think;
    //level.bot_funcs["should_start_cautious_approach"] = ::should_start_cautious_approach_sd;
    //level.bot_funcs["know_enemies_on_start"] = undefined;
    level.bot_funcs["notify_enemy_bots_bomb_used"] = ::notify_enemy_team_bomb_used;
}

bot_dd_start()
{
    setup_bot_dd();
}

_id_90A1( var_0 ) // crate_can_use( crate )
{
    // Agents can only pickup boxes normally
    if ( isagent( self ) && !isdefined( var_0.boxtype ) )
        return 0;

    if ( !maps\mp\_utility::isteamparticipant( self ) )
        return 1;

    // If bot is a team participant but doesn't have a role, 
    // wait for that to get figured out before allowing crate pickup
    if ( !isdefined( self._id_941D ) )
        return 0;

    switch ( self._id_941D )
    {
        case "atk_bomber":
        case "bomb_defuser":
        case "investigate_someone_using_bomb":
            return 0;
    }

    return 1;
}

setup_bot_dd()
{
    // Needs to occur regardless of whether bots are enabled / in play, 
    //so that bot_DrawDebugGametype can be used, 
    //and so that if bots are ever enabled,
    // the targets are already cached 
    //(since it doesn't work to cache them after the bomb has been planted)
    maps\mp\bots\_bots_strategy::_id_168E();
    maps\mp\bots\_bots_util::_id_16C4( 1 );

    dd_has_fatal_error = false;
    foreach( bombzone in level.bombzones )
    {
        zone = getzonenearest( bombzone.curorigin );

        if ( IsDefined( zone ) )
			botzonesetteam( zone, game["defenders"] );
    }

    if ( !dd_has_fatal_error )
    {
        maps\mp\bots\_bots_util::bot_cache_entrances_to_bombzones();
        thread bot_dd_ai_director_update();
        level.bot_gametype_precaching_done = 1;
    }
}

bot_dd_think()
{
    self notify( "bot_dd_think" );
    self endon( "bot_dd_think" );
    self endon( "death" );
    self endon( "disconnect" ); 
    level endon( "game_ended" );

    while ( !isdefined( level.bot_gametype_precaching_done ) )
        wait 0.05;
    
    self botsetflag( "separation", 0 );
    self botsetflag( "grenade_objectives", 1 );

    self.current_bombzone = undefined;
    self.defuser_bad_path_counter = 0;

    for (;;)
    {
        wait 10.0;//0.05;

        if ( isdefined( self.current_bombzone ) && !bombzone_is_active( self.current_bombzone ) )
        {
            self.current_bombzone = undefined;
            self bot_dd_clear_role();
        }

        bot_is_attacker = self.team == game["attackers"];

        if (bot_is_attacker)
        {
            self bot_pick_new_zone( "attack" );

            if ( !isdefined( self.current_bombzone ) )
                continue;

            self bot_try_switch_attack_zone();
            self bot_choose_attack_role();

            if ( self._id_941D == "sweep_zone" )
            {
                if ( !self maps\mp\bots\_bots_util::bot_is_defending_point( self.current_bombzone.curorigin ) )
                {
                    optional_params["min_goal_time"] = 2;
                    optional_params["max_goal_time"] = 4;
                    optional_params["override_origin_node"] = common_scripts\utility::random(self.current_bombzone.botTargets);
                    self maps\mp\bots\_bots_strategy::bot_protect_point( self.current_bombzone.curorigin, level.protect_radius, optional_params );
                }
            }
            else if ( self._id_941D == "defend_zone" )
            {
                if ( !self maps\mp\bots\_bots_util::bot_is_defending_point( level.ddbombmodel[self.current_bombzone.label].origin ) )
                {
                    optional_params["score_flags"] = "strongly_avoid_center";
                    self maps\mp\bots\_bots_strategy::bot_protect_point( level.ddbombmodel[self.current_bombzone.label].origin, level.protect_radius, optional_params );
                }
            }
            else if ( self._id_941D == "investigate_someone_using_bomb" )
                self investigate_someone_using_bomb();
            else if ( self.id_941D == "atk_bomber" )
            {
                //println(self.team + ": Bot " + self.name + " will try to plant bomb.");
                self plant_bomb();
            }
            continue;
        }

        self bot_pick_new_zone( "defend" );

        if ( !isdefined( self.current_bombzone ) )
            continue;

        self bot_choose_defend_role();
        
        if ( self._id_941D == "defend_zone" )
        {
            if ( !self maps\mp\bots\_bots_util::bot_is_defending_point( self.current_bombzone.curorigin ) )
            {
                optional_params["score_flags"] = "strict_los";
                optional_params["override_origin_node"] = common_scripts\utility::random(self.current_bombzone.botTargets);
                self maps\mp\bots\_bots_strategy::bot_protect_point( self.current_bombzone.curorigin, level.protect_radius, optional_params );
            }
            continue;
        }

        if ( self._id_941D == "investigate_someone_using_bomb" )
        {
            self investigate_someone_using_bomb();
            continue;
        }

        if ( self._id_941D == "defuser" )
            //println(self.team + ": Bot " + self.name + " will try to defuse bomb.");
            self defuse_bomb();
    }
}

notify_enemy_team_bomb_used(type)
{
    closest_zone = _id_914F(self);
    players = get_ai_hearing_bomb_plant_sound(type);

    foreach (player in players)
    {
        if ( isdefined( player.current_bombzone ) && closest_zone == player.current_bombzone )
            player bot_dd_set_role( "investigate_someone_using_bomb" );
    }
}

_id_914F( var_0 ) // find_closest_bombzone_to_player
{
    var_1 = undefined;
    var_2 = 999999999;

    foreach ( var_4 in level.bombzones )
    {
        var_5 = distancesquared( var_4.curorigin, var_0.origin );

        if ( var_5 < var_2 )
        {
            var_1 = var_4;
            var_2 = var_5;
        }
    }

    return var_1;
}

get_ai_hearing_bomb_plant_sound( var_0 )
{
    var_1 = [];
    var_2 = get_living_players_on_team( common_scripts\utility::get_enemy_team( self.team ) );

    foreach ( var_4 in var_2 )
    {
        if ( !isai( var_4 ) )
            continue;

        var_5 = 0;

        if ( var_0 == "plant" )
            var_5 = 300 + var_4 botgetdifficultysetting( "strategyLevel" ) * 100;
        else if ( var_0 == "defuse" )
            var_5 = 500 + var_4 botgetdifficultysetting( "strategyLevel" ) * 500;

        if ( distancesquared( var_4.origin, self.origin ) < squared( var_5 ) )
            var_1[var_1.size] = var_4;
    }

    return var_1;
}

get_living_players_on_team( team, only_ai_with_roles )
{
	players = [];
	foreach( player in level.participants )
	{
		if ( !IsDefined( player.team ) )
			continue;

		if ( maps\mp\_utility::isreallyalive(player) && maps\mp\_utility::isteamparticipant(player) && player.team == team )
		{
			if ( !IsDefined(only_ai_with_roles) || ( only_ai_with_roles && IsAI(player) && IsDefined(player._id_941D) ) )
				players[players.size] = player;
		}
	}
	
	return players;
}

plant_bomb()
{
    self endon( "new_role" );

    botTargets_sorted = self get_bombzone_node_to_plant_on( self.current_bombzone, 0 );
    self botsetscriptgoal( botTargets_sorted.origin, 0, "critical" );

    pathResult = self maps\mp\bots\_bots_util::bot_waittill_goal_or_fail();

    if ( pathResult == "goal" )
    {
        time_left = maps\mp\gametypes\_gamelogic::getTimeRemaining();
        time_till_last_chance_to_plant = time_left - (level.plantTime * 2) * 1000;
        last_chance_to_plant = GetTime() + time_till_last_chance_to_plant;

        if ( time_till_last_chance_to_plant > 0 )
        {
            self maps\mp\bots\_bots_util::bot_waittill_out_of_combat_or_time( time_till_last_chance_to_plant );
        }

        emergency_plant = (last_chance_to_plant > 0) && (GetTime() >= last_chance_to_plant);
        //println(self.team + ": Bot " + self.name + " is planting...");
        succeeded = self _id_942D( level.plantTime + 2, "bomb_planted", emergency_plant );
        self botclearscriptgoal();

        if (succeeded)
        {
            //println("Bot planted bomb!");
            self bot_dd_clear_role();
        }
    }
}

get_bombzone_node_to_plant_on( var_0, var_1 )
{
    if ( var_0.bottargets.size >= 2 )
    {
        if ( var_1 )
            var_2 = self botnodescoremultiple( var_0.bottargets, "node_exposed" );
        else
            var_2 = self botnodescoremultiple( var_0.bottargets, "node_hide_anywhere", "ignore_occupancy" );

        var_3 = self botgetdifficultysetting( "strategyLevel" ) * 0.3;
        var_4 = ( self botgetdifficultysetting( "strategyLevel" ) + 1 ) * 0.15;
        var_5 = common_scripts\utility::array_randomize( var_0.bottargets );

        foreach ( var_7 in var_5 )
        {
            if ( !common_scripts\utility::array_contains( var_2, var_7 ) )
                var_2[var_2.size] = var_7;
        }

        if ( randomfloat( 1.0 ) < var_3 )
        {
            return var_2[0];
            return;
        }

        if ( randomfloat( 1.0 ) < var_4 )
        {
            return var_2[1];
            return;
        }

        return common_scripts\utility::random( var_2 );
        return;
        return;
    }
    else
        return var_0.bottargets[0];
}

_id_942D( var_0, var_1, var_2 ) // sd_press_use
{
    var_3 = 0;

    if ( self botgetdifficultysetting( "strategyLevel" ) == 1 )
        var_3 = 40;
    else if ( self botgetdifficultysetting( "strategyLevel" ) >= 2 )
        var_3 = 80;

    if ( randomint( 100 ) < var_3 )
    {
        self botsetstance( "prone" );
        wait 0.2;
    }

    if ( self botgetdifficultysetting( "strategyLevel" ) > 0 && !var_2 )
    {
        thread _id_9369();
        thread notify_on_damage();
    }

    //println(self.team + ": Bot " + self.name + " will try to +use bombsite...");
    self botpressbutton( "use", var_0 );
    var_4 = self maps\mp\bots\_bots_util::bot_usebutton_wait( var_0, var_1, "use_interrupted" );
    self botsetstance( "none" );
    self botclearbutton( "use" );
    var_5 = var_4 == var_1;
    return var_5;
}

_id_9369()
{
    var_0 = _id_914F( self );
    self waittill( "bulletwhizby", var_1 );

    if ( !isdefined( var_1.team ) || var_1.team != self.team )
    {
        var_2 = var_0.usetime - var_0.curprogress;

        if ( var_2 > 1000 )
            self notify( "use_interrupted" );
    }
}

notify_on_damage()
{
    self waittill( "damage", var_0, var_1 );

    if ( !isdefined( var_1.team ) || var_1.team != self.team )
        self notify( "use_interrupted" );
}

SCR_CONST_BOT_DEFUSE_FALLBACK_COUNT = 4;

get_bombzone_node_to_defuse_on( var_0 )
{
    var_1 = self botnodescoremultiple( var_0.bottargets, "node_hide_anywhere", "ignore_occupancy" );
    var_2 = self botgetdifficultysetting( "strategyLevel" ) * 0.3;
    var_3 = ( self botgetdifficultysetting( "strategyLevel" ) + 1 ) * 0.15;
    var_4 = common_scripts\utility::array_randomize( var_0.bottargets );

    foreach ( var_6 in var_4 )
    {
        if ( !common_scripts\utility::array_contains( var_1, var_6 ) )
            var_1[var_1.size] = var_6;
    }

    if ( randomfloat( 1.0 ) < var_2 )
        return var_1[0];
    else if ( randomfloat( 1.0 ) < var_3 )
        return var_1[1];
    else
        return common_scripts\utility::random( var_1 );
}

defuse_bomb()
{
    self endon( "new_role" );
    self botsetpathingstyle( "scripted" );
    
    defuse_target_origin = self get_bombzone_node_to_defuse_on( self.current_bombzone ).origin;
    self botsetscriptgoal( defuse_target_origin, 20, "critical" );

    pathResult = self maps\mp\bots\_bots_util::bot_waittill_goal_or_fail();

    if ( pathResult == "bad_path" )
    {
        self.defuser_bad_path_counter++;

        if ( self.defuser_bad_path_counter >= SCR_CONST_BOT_DEFUSE_FALLBACK_COUNT )
        {
            while(1)
            {
                nodes = GetNodesInRadiusSorted( defuse_target_origin, 50, 0 );
				potential_index = (self.defuser_bad_path_counter - SCR_CONST_BOT_DEFUSE_FALLBACK_COUNT);
				if ( nodes.size <= potential_index )
                {
                    nearest_point = BotGetClosestNavigablePoint(defuse_target_origin, 50, self);

                    if ( isdefined( nearest_point ) )
                        self BotSetScriptGoal( nearest_point, 20, "critical" );
                    else
                        break;
                }
				else
				    self BotSetScriptGoal( nodes[potential_index].origin, 20, "critical" );

				pathResult = self maps\mp\bots\_bots_util::bot_waittill_goal_or_fail();
				if ( pathResult == "bad_path" )
                {
					self.defuser_bad_path_counter++;
                    continue;
                }

				break;
            }
        }
    }

    if ( pathResult == "goal" )
    {
        wait_time = self.current_bombzone.waittime * 1000;
        time_till_last_chance_to_defuse = wait_time - (level.defuseTime * 2) * 1000;
        last_chance_to_defuse = GetTime() + time_till_last_chance_to_defuse;

        if ( time_till_last_chance_to_defuse > 0 )
        {
            self maps\mp\bots\_bots_util::bot_waittill_out_of_combat_or_time( time_till_last_chance_to_defuse );
        }

        emergency_defuse = (last_chance_to_defuse > 0) && (GetTime() >= last_chance_to_defuse);
        succeeded = self _id_942D( level.defusetime + 2, "bomb_defused", emergency_defuse );

        if ( !succeeded && self.defuser_bad_path_counter >= SCR_CONST_BOT_DEFUSE_FALLBACK_COUNT )
        {
            self.defuser_bad_path_counter++;
        }

        self botclearscriptgoal();

        if (succeeded)
        {
            //println("Bot defused bomb!");
            self bot_dd_clear_role();
        }
    }
}

investigate_someone_using_bomb()
{
    self endon("new_role");

    if ( self maps\mp\bots\_bots_util::bot_is_defending() )
        self maps\mp\bots\_bots_strategy::bot_defend_stop();

    self botsetscriptgoalnode( common_scripts\utility::random( self.current_bombzone.bottargets ), "critical" );

    pathResult = self maps\mp\bots\_bots_util::bot_waittill_goal_or_fail();

    if ( pathResult == "goal" )
    {
        wait 2;
        self bot_dd_clear_role();
    }
}

get_player_defusing_zone( var_0 )
{
    var_1 = get_players_at_zone( var_0, self.team );

    foreach ( var_3 in var_1 )
    {
        if ( !isai( var_3 ) )
        {
            if ( var_3.isdefusing )
                return var_3;
        }
    }

    foreach ( var_3 in var_1 )
    {
        if ( isai( var_3 ) )
        {
            if ( isdefined( var_3._id_941D ) && var_3._id_941D == "defuser" )
                return var_3;
        }
    }

    return undefined;
}

get_player_planting_zone( var_0 )
{
    var_1 = get_players_at_zone( var_0, self.team );

    foreach ( var_3 in var_1 )
    {
        if ( !isai( var_3 ) )
        {
            if ( var_3.isplanting )
                return var_3;
        }
    }

    foreach ( var_3 in var_1 )
    {
        if ( isai( var_3 ) )
        {
            if ( isdefined( var_3._id_941D ) && var_3._id_941D == "atk_bomber" )
                return var_3;
        }
    }

    return undefined;
}

bombzone_is_active( var_0 )
{
    if ( var_0._id_89F5 == "any" ) // visibleteam
    {
        //println("Bombzone " + var_0.label + " is active");
        //println( "Disabled Trigger: " + var_0.trigger.trigger_off );
        return 1;
    }

    //println("Bombzone " + var_0.label + " is inactive");
    //println( "Disabled Trigger: " + var_0.trigger.trigger_off );
    return 0;
    
    /*if ( var_0.visibleteam == "any" )
    {
        println("Bombzone " + var_0.label + " is active");
        println( "Disabled Trigger: " + var_0.trigger.trigger_off );
        return 1;
    }

    println("Bombzone " + var_0.label + " is inactive");
    println( "Disabled Trigger: " + var_0.trigger.trigger_off );
    return 0;
    */

    /*
    if ( isdefined(var_0.trigger.trigger_off) && var_0.trigger.trigger_off == true )
    {
        //println( "Bombzone " + var_0.label + " is inactive" );
        //println( "Disabled Trigger: " + var_0.trigger.trigger_off );
        return 0;
    }

    //println( "Bombzone " + var_0.label + " is active" );
    //println( "Disabled Trigger: " + var_0.trigger.trigger_off );
    return 1;
    */
}

get_active_bombzones()
{
    var_0 = [];

    foreach ( var_2 in level.bombzones )
    {
        if ( bombzone_is_active( var_2 ) )
            var_0[var_0.size] = var_2;
    }

    return var_0;
}

get_players_at_zone( var_0, var_1 )
{
    var_2 = [];
    var_3 = get_living_players_on_team( var_1 );

    foreach ( var_5 in var_3 )
    {
        if ( isai( var_5 ) )
        {
            if ( isdefined( var_5.current_bombzone ) && var_5.current_bombzone == var_0 )
                var_2 = common_scripts\utility::array_add( var_2, var_5 );

            continue;
        }

        if ( distancesquared( var_5.origin, var_0.curorigin ) < level.protect_radius * level.protect_radius )
            var_2 = common_scripts\utility::array_add( var_2, var_5 );
    }

    return var_2;
}

bot_pick_dd_zone_with_fewer_defenders( var_0, var_1 )
{
    var_2[0] = get_players_at_zone( var_0[0], game["defenders"] ).size;
    var_2[1] = get_players_at_zone( var_0[1], game["defenders"] ).size;

    if ( var_2[0] > var_2[1] + var_1 )
        return var_0[1];
    else if ( var_2[0] + var_1 < var_2[1] )
        return var_0[0];
}

bot_pick_new_zone( var_0 )
{
    var_1 = undefined;

    if ( var_0 == "attack" )
        var_1 = bot_choose_attack_zone();
    else if ( var_0 == "defend" )
        var_1 = bot_choose_defend_zone();

    if ( isdefined( var_1 ) && ( !isdefined( self.current_bombzone ) || self.current_bombzone != var_1 ) )
    {
        self.current_bombzone = var_1;
        self bot_dd_clear_role();
    }
}

bot_choose_defend_zone()
{
    var_0 = get_active_bombzones();
    var_1 = undefined;

    if ( var_0.size == 1 )
        var_1 = var_0[0];
    else if ( var_0.size == 2 )
    {
        var_2[0] = get_players_at_zone( var_0[0], game["defenders"] ).size;
        var_2[1] = get_players_at_zone( var_0[1], game["defenders"] ).size;
        var_3[0] = is_bomb_planted_on( var_0[0] );
        var_3[1] = is_bomb_planted_on( var_0[1] );

        if ( var_3[0] && var_3[1] || !var_3[0] && !var_3[1] )
        {
            var_4 = 0;

            if ( isdefined( self.current_bombzone ) )
                var_4 = 1;

            var_1 = self bot_pick_dd_zone_with_fewer_defenders( var_0, var_4 );

            if ( !isdefined( var_1 ) && !isdefined( self.current_bombzone ) )
                var_1 = common_scripts\utility::random( var_0 );
        }
        else if ( var_3[0] || var_3[1] )
        {
            var_5 = common_scripts\utility::ter_op( var_3[0], 0, 1 );
            var_6 = common_scripts\utility::ter_op( !var_3[0], 0, 1 );

            if ( var_2[var_5] > var_2[var_6] + 2 )
                var_1 = var_0[var_6];
            else if ( var_2[var_5] <= var_2[var_6] )
                var_1 = var_0[var_5];
            else if ( !isdefined( self.current_bombzone ) )
            {
                if ( var_2[var_5] >= var_2[var_6] + 2 )
                    var_1 = var_0[var_6];
                else if ( var_2[var_5] < var_2[var_6] + 2 )
                    var_1 = var_0[var_5];
            }
        }
    }

    return var_1;
}

get_other_active_zone( var_0 )
{
    var_1 = get_active_bombzones();

    foreach ( var_3 in var_1 )
    {
        if ( var_3 != var_0 )
            return var_3;
    }
}

bot_choose_attack_zone()
{
    if ( isdefined( self.current_bombzone ) )
        return;

    if ( !isdefined( level.current_zone_target ) || !bombzone_is_active( level.current_zone_target ) || gettime() > level.next_target_switch_time )
    {
        level.next_target_switch_time = gettime() + 1000 * randomintrange( 30, 45 );
        level.current_zone_target = common_scripts\utility::random( get_active_bombzones() );
    }

    if ( !isdefined( level.current_zone_target ) )
        return;

    var_0 = level.current_zone_target;
    var_1 = get_other_active_zone( var_0 );
    self.current_bombzone = undefined;

    if ( isdefined( var_1 ) )
    {
        if ( randomfloat( 1.0 ) < 0.25 )
            return var_1;
    }

    return var_0;
}

bot_try_switch_attack_zone()
{
    var_0 = get_other_active_zone( self.current_bombzone );

    if ( isdefined( var_0 ) )
    {
        var_1 = distance( self.origin, self.current_bombzone.curorigin );
        var_2 = distance( self.origin, var_0.curorigin );

        if ( var_2 < var_1 * 0.6 )
            self.current_bombzone = var_0;
    }
}

bot_choose_attack_role()
{
    if ( isdefined( self._id_941D ) )
    {
        if ( self._id_941D == "investigate_someone_using_bomb" )
            return;
    }

    var_0 = undefined;

    if ( is_bomb_planted_on( self.current_bombzone ) )
        var_0 = "defend_zone";
    else
    {
        var_1 = get_player_planting_zone( self.current_bombzone );

        if ( !isdefined( var_1 ) || var_1 == self )
            var_0 = "atk_bomber";
        else if ( isai( var_1 ) )
        {
            var_2 = distance( self.origin, self.current_bombzone.curorigin );
            var_3 = distance( var_1.origin, self.current_bombzone.curorigin );

            if ( var_2 < var_3 * 0.9 )
            {
                var_0 = "atk_bomber";
                var_1 bot_dd_clear_role();
            }
        }
    }

    if ( !isdefined( var_0 ) )
        var_0 = "sweep_zone";

    self bot_dd_set_role( var_0 );
}

bot_choose_defend_role()
{
    if ( isdefined( self._id_941D ) )
    {
        if ( self._id_941D == "investigate_someone_using_bomb" )
            return;
    }

    var_0 = undefined;

    if ( is_bomb_planted_on( self.current_bombzone ) )
    {
        var_1 = get_player_defusing_zone( self.current_bombzone );

        if ( !isdefined( var_1 ) || var_1 == self )
            var_0 = "defuser";
        else if ( isai( var_1 ) )
        {
            var_2 = distance( self.origin, self.current_bombzone.curorigin );
            var_3 = distance( var_1.origin, self.current_bombzone.curorigin );

            if ( var_2 < var_3 * 0.9 )
            {
                var_0 = "defuser";
                var_1 bot_dd_clear_role();
            }
        }
    }

    if ( !isdefined( var_0 ) )
        var_0 = "defend_zone";

    self bot_dd_set_role( var_0 );
}

bot_dd_set_role( var_0 )
{
    if ( !isdefined( self._id_941D ) || self._id_941D != var_0 )
    {
        self bot_dd_clear_role();
        self._id_941D = var_0;
    }
}

bot_dd_clear_role()
{
    self._id_941D = undefined;
    self botclearscriptgoal();
    self botsetpathingstyle( undefined );
    self maps\mp\bots\_bots_strategy::bot_defend_stop();
    self notify( "new_role" );
    self.defuser_bad_path_counter = 0;
}

bot_dd_ai_director_update()
{
    level notify( "bot_dd_ai_director_update" );
    level endon( "bot_dd_ai_director_update" );
    level endon( "game_ended" );
    level.protect_radius = 725;

    for (;;)
    {
        foreach ( var_1 in level.bombzones )
        {
            foreach ( var_3 in level.players )
            {
                if ( isdefined( var_3._id_941D ) && isdefined( var_3.current_bombzone ) && var_3.current_bombzone == var_1 )
                {
                    if ( !bombzone_is_active( var_1 ) )
                    {
                        if ( var_3._id_941D == "atk_bomber" || var_3._id_941D == "defuser" )
                            var_3 bot_dd_clear_role();

                        continue;
                    }

                    if ( is_bomb_planted_on( var_1 ) )
                    {
                        if ( var_3._id_941D == "atk_bomber" )
                            var_3 bot_dd_clear_role();
                    }
                }
            }
        }

        wait 0.5;
    }
}

is_bomb_planted_on( var_0 )
{
    return isdefined( var_0.bombplantedon ) && var_0.bombplantedon;
}
