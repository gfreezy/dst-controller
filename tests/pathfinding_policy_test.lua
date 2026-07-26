local Policy = require("dst-controller/utils/pathfinding-policy")

assert(math.abs(Policy.EstimateCost(0, 0, 3, 0) - 3 * 0.77) < 0.0001,
    "straight A* estimates should use the cheapest terrain cost")
assert(math.abs(Policy.EstimateCost(0, 0, 2, 2) - 2 * 1.414 * 0.77) < 0.0001,
    "diagonal A* estimates should use octile distance")
assert(Policy.EstimateCost(5, -2, 5, -2) == 0,
    "the A* heuristic should be zero at the destination")
assert(math.abs(Policy.EstimateWeightedCost(0, 0, 3, 0, 1.3) -
    3 * 0.77 * 1.3) < 0.0001,
    "weighted A* should scale the admissible base heuristic")
