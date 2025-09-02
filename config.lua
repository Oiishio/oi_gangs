-- config.lua - Single configuration file for all gangs
Config = {}

-- Global settings
Config.DrawDistance = 10.0
Config.MarkerType = {Cloakrooms = 20, Armories = 21, BossActions = 22, Vehicles = 36}
Config.MarkerSize = {x = 1.5, y = 1.5, z = 0.5}
Config.EnablePlayerManagement = true
Config.EnableArmoryManagement = true
Config.EnableJobBlip = true
Config.EnableESXService = true
Config.MaxInService = 128
Config.EnableCustomPeds = false
Config.Locale = 'en'

-- Define all your gangs here
Config.Gangs = {
    ['gauja'] = {
        name = 'Dantistų Gauja',
        blipSprite = 126,
        blipColor = 1,
        markerColor = {r = 120, g = 0, b = 0},
        bossRank = 4,
        
        locations = {
            main = vec3(-1096.8022, 823.4803, 168.8391),
            cloakroom = vec3(-1092.4176, 824.6220, 168.6373),
            boss = vec3(-1253.5382, 796.4688, 197.2051),
            npc = { 
                coords = vec3(2588.2419, 3167.7783, 51.3673), 
                rotation = 315.9071, 
                model = 'ig_ramp_gang' 
            },
            vehicles = {
                spawner = vec3(-684.7240, -891.4246, 24.4990),
                shop = vec3(2586.0039, 3180.0513, 51.1305),
                spawnPoints = {
                    {coords = vec3(-669.8652, -877.6219, 24.1006), heading = 96.4288, radius = 6.0}
                }
            }
        },

        vehicles = {
            officer = { {model = 'sanchez', price = 0} },
            sergeant = { {model = 'sanchez', price = 0} },
            lieutenant = { {model = 'sanchez', price = 0} },
            boss = { {model = 'sanchez', price = 0} }
        },

        uniforms = {
            male = {
                {
                    name = 'Dantistų Gaujos Uniforma [1]',
                    components = {
                        { component_id = 11, drawable = 2, texture = 0 },
                        { component_id = 4, drawable = 2, texture = 5 },
                        { component_id = 6, drawable = 2, texture = 1 },
                    },
                    props = {
                        { prop_id = 0, drawable = 12, texture = 1 },
                    }
                },
                {
                    name = 'Dantistų Gaujos Neperš aunama Liemenė [1]',
                    armour = true,
                    components = {
                        {component_id = 9, texture = 7, drawable = 96},
                    },
                }
            },
            female = {
                {
                    name = 'Dantistų Gaujos Uniforma [1]',
                    components = {
                        {drawable = 0, texture = 0, component_id = 0}, 
                        {drawable = 25, texture = 0, component_id = 3}, 
                        {drawable = 196, texture = 0, component_id = 4}, 
                        {drawable = 22, texture = 0, component_id = 6}, 
                        {drawable = 261, texture = 0, component_id = 8}, 
                        {drawable = 345, texture = 0, component_id = 11}
                    },             
                    props = {
                        {drawable = 16, prop_id = 2, texture = 0}, 
                    }
                },
                {
                    name = 'Dantistų Gaujos Neperš aunama Liemenė [1]',
                    armour = true,
                    components = {
                        {drawable = 78, texture = 1, component_id = 9}, 
                    },
                }
            }
        }
    },
    
    ['mafia'] = {
        name = 'Italian Mafia',
        blipSprite = 156,
        blipColor = 0,
        markerColor = {r = 0, g = 0, b = 120},
        bossRank = 4,
        
        locations = {
            main = vec3(-1000.0, 800.0, 170.0),
            cloakroom = vec3(-1005.0, 805.0, 170.0),
            boss = vec3(-1010.0, 810.0, 170.0),
            npc = { 
                coords = vec3(2500.0, 3100.0, 50.0), 
                rotation = 0.0, 
                model = 'g_m_m_armlieut_01' 
            },
            vehicles = {
                spawner = vec3(-1020.0, 820.0, 165.0),
                shop = vec3(-1025.0, 825.0, 165.0),
                spawnPoints = {
                    {coords = vec3(-1030.0, 830.0, 165.0), heading = 180.0, radius = 6.0}
                }
            }
        },

        vehicles = {
            associate = { {model = 'blista', price = 0} },
            soldier = { {model = 'sultan', price = 0} },
            capo = { {model = 'schafter2', price = 0} },
            boss = { {model = 'cognoscenti', price = 0} }
        },

        uniforms = {
            male = {
                {
                    name = 'Mafia Suit [1]',
                    components = {
                        { component_id = 11, drawable = 4, texture = 0 },
                        { component_id = 4, drawable = 10, texture = 0 },
                        { component_id = 6, drawable = 10, texture = 0 },
                    }
                }
            },
            female = {
                {
                    name = 'Mafia Dress [1]',
                    components = {
                        {drawable = 15, texture = 0, component_id = 3}, 
                        {drawable = 27, texture = 0, component_id = 4}, 
                        {drawable = 27, texture = 0, component_id = 6}, 
                        {drawable = 2, texture = 0, component_id = 8}, 
                        {drawable = 7, texture = 0, component_id = 11}
                    }
                }
            }
        }
    }
}

-- Localization
Config.Locales = {
    ['vehicle_menu'] = 'Transporto priemonės meniu',
    ['vehicle_blocked'] = 'Išėjimas užblokuotas.',
    ['garage_title'] = 'Veiksmai',
    ['garage_stored'] = 'Garaze',
    ['garage_notstored'] = 'Ne garaze',
    ['garage_storing'] = 'Bandoma įstatyti transporto priemonę',
    ['garage_has_stored'] = 'Transporto priemonė sėkmingai įdėta į garazą',
    ['garage_has_notstored'] = 'Transporto priemonė nerasta',
    ['garage_notavailable'] = 'Negalima pastatyti šios transporto priemonės.',
    ['garage_blocked'] = 'Išėjimas užblokuotas',
    ['garage_empty'] = 'Jūs neturite transporto priemonių garaze',
    ['garage_released'] = 'Transporto priemonė sėkmingai išimta iš garazo.',
    ['garage_store_nearby'] = 'Šalia nėra transporto priemonių.',
    ['shop_item'] = 'NEMOKAMA',
    ['cloakroom'] = 'GANG PERSIRANGYMO KAMBARYS',
    ['garage_storeditem'] = 'Atidaryti garazą',
    ['garage_storeitem'] = 'Įdėti transporto priemonę',
    ['garage_buyitem'] = 'Transporto priemonių parduotuvė',
    ['garage_notauthorized'] = 'Nėra priskirtų transporto priemonių',
    ['vehicleshop_title'] = 'Transporto priemonės pasirinkimas',
    ['vehicleshop_confirm'] = 'Ar norite šios transporto priemonės?',
    ['vehicleshop_bought'] = 'Transporto priemonė sėkmingai gauta',
    ['vehicleshop_awaiting_model'] = 'Transporto priemonė kraunama, prašome palaukti...',
    ['confirm_no'] = 'Ne',
    ['confirm_yes'] = 'Taip',
    ['service_in'] = 'Įžengė į nusikalstamą gyvenimą',
    ['service_out'] = 'Grįžo į civilinį gyvenimą',
    ['cuff_person'] = 'Surišti asmenį',
    ['drag_person'] = 'Tempti asmenį', 
    ['put_in_vehicle'] = 'Įdėti į transporto priemonę',
    ['search_person'] = 'Apžiūrėti asmenį',
    ['remove_from_vehicle'] = 'Pašalinti surištus asmenis iš transporto priemonės',
    ['storage'] = 'Sandėlis',
    ['boss_storage'] = 'Boso sandėlis',
    ['change_clothes'] = 'Persirengti',
    ['boss_menu'] = 'Boso meniu',
    ['civilian_clothes'] = 'Civiliniai drabužiai',
    ['civilian_clothes_desc'] = 'Persirengti civiliniais drabužiais',
    ['work_uniform'] = 'Darbo uniforma',
    ['wardrobe'] = 'Spinta',
    ['changing_clothes'] = 'Persirengiama...',
    ['stop_dragging'] = 'Nustoti tempti',
    ['handcuffing_player'] = 'Surakinamas žaidėjas...',
    ['try_break_free'] = 'Paspausk [G], kad pabandytum išsivaduoti!',
    ['player_cuffed'] = 'Žaidėjas sėkmingai surakintas',
    ['player_resisted'] = 'Žaidėjas priešinosi!',
    ['broke_free'] = 'Išsivadavai!',
    ['handcuffing_failed'] = 'Nepavyko surakinti',
    ['no_ziptie'] = 'Reikia antrankių',
    ['already_cuffed'] = 'Žaidėjas jau surakintas',
    ['being_processed'] = 'Žaidėjas jau rakinamas',
    ['uncuffing_player'] = 'Atrakinamas...',
    ['player_uncuffed'] = 'Žaidėjas sėkmingai atrakintas',
    ['not_cuffed'] = 'Žaidėjas nėra surakintas',
    ['handcuff_cancelled'] = 'Surakinimas buvo atšauktas'

}

return Config