CxAtmRob = CxAtmRob or {}

CxAtmRob.Machines = {
    cortex_atm_01 = { open = 'cortex_atm_01_open', vanilla = 'prop_atm_01', bay = vec3(0.0, -0.236, 0.475), label = 'machine.store' },
    cortex_atm_fleeca = { open = 'cortex_atm_fleeca_open', vanilla = 'prop_fleeca_atm', bay = vec3(0.0, -0.116, 0.5425), label = 'machine.fleeca' },
    cortex_atm_02 = { open = 'cortex_atm_02_open', vanilla = 'prop_atm_02', bay = vec3(0.0, -0.099, 0.5445), label = 'machine.street' },
    cortex_atm_03 = { open = 'cortex_atm_03_open', vanilla = 'prop_atm_03', bay = vec3(0.0, -0.099, 0.5445), label = 'machine.street' },
}

CxAtmRob.Stages = { door = 1, plate = 2, wires = 3, cassette = 4, empty = 5, dead = 5 }
CxAtmRob.Reach = 3.0
CxAtmRob.PryPoints = 3
CxAtmRob.ScrewCount = 4
CxAtmRob.WireCount = 6
CxAtmRob.SlotCount = 18
CxAtmRob.SlotsPerLayer = 6
