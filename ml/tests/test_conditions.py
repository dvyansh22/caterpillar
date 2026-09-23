import numpy as np
import pytest

from ml.features import conditions as c
from ml.features import weather as wx


@pytest.mark.parametrize(("temp", "rh", "wbgt"), [(35, 60, 30.4), (42, 25, 30.7), (22, 50, 17.4)])
def test_wbgt_known_values(temp, rh, wbgt):
    assert float(c.wbgt_c(temp, rh)) == pytest.approx(wbgt, abs=0.2)


def test_heat_work_rest_schedule():
    assert float(c.work_fraction(27.9, 12)) == 1.0
    assert float(c.work_fraction(28.5, 12)) == 0.75
    assert float(c.work_fraction(29.5, 12)) == 0.50
    assert float(c.work_fraction(31.0, 12)) == 0.25


def test_ac_cab_softens_heat():
    open_cab, ac_cab = float(c.work_fraction(31.0, 12)), float(c.work_fraction(31.0, 3))
    assert open_cab < ac_cab < 1.0


def test_visibility_hits_haul_tasks_hardest_and_stops_below_200m():
    assert float(c.visibility_multiplier(5000, True)) == 1.0
    assert float(c.visibility_multiplier(600, True)) > float(c.visibility_multiplier(600, False)) > 1.0
    assert float(c.visibility_multiplier(150, True)) > float(c.visibility_multiplier(250, True))


def test_wet_ground_depends_on_material():
    assert float(c.wet_ground_multiplier(0, "Clay")) == 1.0
    assert float(c.wet_ground_multiplier(5, "Clay")) > float(c.wet_ground_multiplier(5, "Rock")) > 1.0


def test_works_on_arrays():
    out = c.assess(np.array([22, 38]), np.array([50, 60]), np.array([15000, 150]), np.array([0, 9]),
                   np.array(["Rock", "Clay"]), np.array([3, 12]), np.array([False, True]))
    assert out["HeatMultiplier"][0] == 1.0 and out["HeatMultiplier"][1] > 1.0
    assert out["VisibilityMultiplier"][1] > 1.0 and out["WetMultiplier"][1] > 1.0


def test_explain_minutes_sum_to_condition_delay():
    effects = c.assess(38, 60, 600, 5, "Clay", 12, True)
    eta = 200.0
    factors, advisories = c.explain(eta, effects, 12, 600, 5)
    base = eta / (float(effects["HeatMultiplier"]) * float(effects["VisibilityMultiplier"]) * float(effects["WetMultiplier"]))
    assert sum(f["minutes"] for f in factors) == pytest.approx(eta - base, abs=0.2)
    assert {f["name"] for f in factors} == {"heat breaks", "low visibility", "wet ground"}
    assert any("Heat" in a for a in advisories)


def test_weather_label_from_conditions():
    labels = wx.weather_label([30, 20, 25, 25], [40, 90, 40, 50], [5, 5, 45, 5], [15000, 15000, 15000, 15000],
                              [0, 3, 0, 0])
    assert list(labels) == ["Sunny", "Rainy", "Windy", "Sunny"]
