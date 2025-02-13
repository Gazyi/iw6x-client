#include <std_include.hpp>
#include "loader/component_loader.hpp"
#include "game/game.hpp"

#include "command.hpp"
#include "console.hpp"
#include "scheduler.hpp"

#include <utils/hook.hpp>
#include <utils/string.hpp>

namespace map_rotation
{
	namespace
	{
		void set_dvar(const std::string& dvar, const std::string& value)
		{
			command::execute(utils::string::va("%s \"%s\"", dvar.data(), value.data()), true);
		}

		void set_gametype(const std::string& gametype)
		{
			set_dvar("g_gametype", gametype);
		}

		void launch_map(const std::string& mapname)
		{
			command::execute(utils::string::va("map %s", mapname.data()), false);
		}

		void launch_default_map()
		{
			auto* mapname = game::Dvar_FindVar("mapname");
			if (mapname && mapname->current.string && strlen(mapname->current.string))
			{
				launch_map(mapname->current.string);
			}
			else
			{
				launch_map("mp_prisonbreak");
			}
		}

		std::string load_current_map_rotation()
		{
			auto* rotation = game::Dvar_FindVar("sv_mapRotationCurrent");
			if (!strlen(rotation->current.string))
			{
				rotation = game::Dvar_FindVar("sv_mapRotation");
				set_dvar("sv_mapRotationCurrent", rotation->current.string);
			}

			return rotation->current.string;
		}

		std::vector<std::string> parse_current_map_rotation()
		{
			const auto rotation = load_current_map_rotation();
			return utils::string::split(rotation, ' ');
		}

		void store_new_rotation(const std::vector<std::string>& elements, const size_t index)
		{
			std::string value{};

			for (auto i = index; i < elements.size(); ++i)
			{
				if (i != index)
				{
					value.push_back(' ');
				}

				value.append(elements[i]);
			}

			set_dvar("sv_mapRotationCurrent", value);
		}

		void perform_map_rotation()
		{
			if (game::Live_SyncOnlineDataFlags(0) != 0)
			{
				scheduler::on_game_initialized(perform_map_rotation, scheduler::pipeline::main, 1s);
				return;
			}

			const auto rotation = parse_current_map_rotation();

			for (size_t i = 0; !rotation.empty() && i < (rotation.size() - 1); i += 2)
			{
				const auto& key = rotation[i];
				const auto& value = rotation[i + 1];

				if (key == "gametype")
				{
					set_gametype(value);
				}
				else if (key == "map")
				{
					store_new_rotation(rotation, i + 2);
					launch_map(value);
					return;
				}
				else
				{
					console::info("Invalid map rotation key: %s\n", key.data());
				}
			}


			launch_default_map();
		}

		void trigger_map_rotation()
		{
			scheduler::schedule([]
			{
				if (game::CL_IsCgameInitialized())
				{
					return scheduler::cond_continue;
				}

				command::execute("map_rotate", false);
				return scheduler::cond_end;
			}, scheduler::pipeline::main, 1s);
		}
	}

	class component final : public component_interface
	{
	public:
		void post_unpack() override
		{
			if (!game::environment::is_dedi())
			{
				return;
			}

			scheduler::once([]()
			{
				game::Dvar_RegisterString("sv_mapRotation", "", game::DvarFlags::DVAR_FLAG_NONE, "");
				game::Dvar_RegisterString("sv_mapRotationCurrent", "", game::DvarFlags::DVAR_FLAG_NONE, "");
			}, scheduler::pipeline::main);

			command::add("map_rotate", &perform_map_rotation);

			// Hook SV_MatchEnd in GScr_ExitLevel 
			utils::hook::jump(0x1403CBC30, &trigger_map_rotation);
			//utils::hook::call(0x1403CBC6C, &trigger_map_rotation);
		}
	};
}

REGISTER_COMPONENT(map_rotation::component)
