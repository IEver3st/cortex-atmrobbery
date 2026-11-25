CxAtmRob = CxAtmRob or {}

CxAtmRob.Wiring = {
    colours = { 'red', 'blue', 'yellow', 'green', 'white', 'black' },
    hex = {
        red = '#d8473d',
        blue = '#3f7fe0',
        yellow = '#e8c33a',
        green = '#3fae5a',
        white = '#e9e6dc',
        black = '#2a2a2c',
    },
    readings = {
        steady = { value = 24.0, unit = 'V DC', mode = 'steady' },
        pulse = { value = 12.0, unit = 'V DC', mode = 'pulse' },
        faint = { value = 3.1, unit = 'V DC', mode = 'steady' },
        mains = { value = 231.0, unit = 'V AC', mode = 'mains' },
        dead = { value = 0.0, unit = 'V DC', mode = 'steady' },
    },
}
