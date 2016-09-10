#define UP 1
#define DOWN -1
#define NONE 0

//ZigZag variables
int zz_confirm = 0;
int zz_direction = NONE;

/**
 * Evaluate ZigZag indicator to determine current movement
 */
int evalZZ(string symbol) {
    int points = 0;
    double p0 = 0.0, p1 = 0.0;
    int i = 1;
    while(points < 2) {
        double zg = iCustom(symbol, 0, "ZigZag", 15, 30, 0, 0, i);
        if(zg != 0.0) {
            points++;
            if(points == 1)
                p0 = zg;
            if(points == 2)
                p1 = zg;
        }
        i++;
    }
    if(p0 - p1 > 0 && zz_direction <= NONE) {
        if(zz_confirm <= 0)
            zz_confirm++;
        else {
            zz_confirm = 0;
            zz_direction = UP;
        }
    }
    else if(p0 - p1 < 0 && zz_direction >= NONE) {
        if(zz_confirm >= 0)
            zz_confirm--;
        else {
            zz_confirm = 0;
            zz_direction = DOWN;
        }
    }
    
    return NONE;
}