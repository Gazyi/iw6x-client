// IW6 GSC SOURCE
// Decompiled by https://github.com/xensik/gsc-tool

main()
{
    _id_710C();
}

_id_710C()
{
    level._id_09CB["player"]["think"] = ::_id_8F40;
}

_id_8F40()
{
    common_scripts\utility::_enableusability();
    thread maps\mp\bots\_bots_gametype_sd::bot_dd_think();
}
