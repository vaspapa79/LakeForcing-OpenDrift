# LakeForcing: a σ-to-z coupling algorithm and open pipeline for hydrodynamic and wind-wave forcing of inland lakes to drive Lagrangian transport models

Vassilios Papaioannou^1,\*, Christos G. E. Anagnostopoulos^1, Dimitrios Valsamis^1, Anastasia Moumtzidou^1, Ilias Gialampoukidis^1, Stefanos Vrochidis^1, Ioannis Kompatsiaris^1

^1 Information Technologies Institute, Centre for Research and Technology Hellas (CERTH-ITI), 6th km Charilaou-Thermi, 57001 Thessaloniki, Greece

ORCID iDs: Vassilios Papaioannou 0000-0001-6598-7107; Christos G. E. Anagnostopoulos 0009-0006-9839-4870; Dimitrios Valsamis 0009-0002-6699-4426; Anastasia Moumtzidou 0000-0001-7615-8400; Ilias Gialampoukidis 0000-0002-5234-9795; Stefanos Vrochidis 0000-0002-2505-9178; Ioannis Kompatsiaris 0000-0001-6447-9020

\*Corresponding author: Vassilios Papaioannou, vaspapa@iti.gr, Tel. +30 697 285 4287

---

## Abstract
Lagrangian particle tracking is a standard tool for transport of floating material
(plastics, oil, harmful-algal-bloom cells, fish larvae), yet in inland lakes its use is blocked
by the absence of ready-made forcing: ocean reanalyses stop at the coast, and lake models are
built by hand. We present LakeForcing, an open, reproducible Python pipeline that
assembles bathymetry and meteorology from open data, automatically runs a coupled
Delft3D-FLOW/WAVE (SWAN) simulation for any lake, and exports CF-compliant NetCDF that drives
Lagrangian particle trackers unmodified. The computational core is a σ-to-z coupling algorithm,
mapping terrain-following σ-layer fields to fixed z-levels with per-cell velocity rotation and
a surface Stokes-drift derivation, that makes a hydrodynamic engine interoperable with a
generic tracker. We demonstrate it, unchanged, on twelve lakes (36°S–60°N); in a consistency check against an
expert-built reference model of one reservoir it reproduces that model's surface temperature to
0.85 °C RMSE and current speed to 1.5 cm s⁻¹, and an independent satellite comparison bounds
the absolute accuracy of the exported surface-temperature field. Toolchain and the twelve-lake
forcing dataset are released openly with a pinned software environment and a continuous-integration
test that reproduces the σ-to-z export from a clean checkout.

**Keywords:** Lake hydrodynamics; Delft3D; OpenDrift; Stokes drift; Sigma-to-z coupling;
Reproducible open-source workflow

---

## Graphical abstract

[[GRAPHICAL_ABSTRACT]]

---

## 1. Introduction

Lagrangian particle-tracking models such as OpenDrift (Dagestad et al., 2018) and Parcels
(Delandmeter and van Sebille, 2019) are standard tools for tracking floating material — plastic
debris, oil, harmful-algal-bloom cells, fish larvae (Iskandar et al., 2022; Wynne and Stumpf, 2015;
Zhou et al., 2023). A floating particle moves with the near-surface current, a wind term and the
wave-driven Stokes drift
(van den Bremer and Breivik, 2018); dropping the Stokes term biases the predicted paths and
accumulation zones (Kukulka et al., 2012; Onink et al., 2019; van Sebille et al., 2020). In the open
ocean all three fields are provided operationally (e.g., the Copernicus Marine Service), so the work
reduces to particle physics rather than making forcing.

Inland waters break this workflow, even though lakes and reservoirs hold most of Earth's liquid
surface freshwater (Lehner et al., 2011; Messager et al., 2016) and receive heavy plastic pollution:
surveys found debris in all 38 lakes sampled, locally above ocean levels (Cózar et al., 2014; Free et
al., 2014; Nava et al., 2023), with morphometry and residence time controlling retention (Wagner et
al., 2014; Chen et al., 2024). Ready-made forcing is
unavailable for lakes, for three reasons. First, ocean reanalyses stop at the coast and hold no data
inside lakes. Second, three-dimensional lake models are well validated (Wüest and Lorke, 2003; Hipsey
et al., 2019; Ishikawa et al., 2022) but built by hand for each lake, which is slow and
non-transferable. Third, cheaper setups use idealised flow that omits the waves, Stokes drift and
heat-driven circulation that dominate surface transport.

The result is a forcing bottleneck. Existing frameworks narrow it but do not close it: CaMPSim-3D
(Pilechi et al., 2022) couples 3-D hydrodynamics to particle transport but is tied to one engine and
set up per site. We know of no open, reproducible workflow that turns globally available data into
transport-ready lake forcing — waves and Stokes drift included — while staying lake-agnostic and
tracker-independent.

This paper presents such a workflow (Table 1). From a lake's coordinates alone, it builds bathymetry
from open datasets (HydroLAKES, Messager et al., 2016; GLOBathy, Khazaei et al., 2022; or DAHITI
altimetry, Schwatke et al., 2015) and ERA5 meteorology (Hersbach et al., 2020), runs a coupled
Delft3D-FLOW (Lesser et al., 2004) and Delft3D-WAVE/SWAN (Booij et al., 1999) simulation, and exports
CF NetCDF that OpenDrift reads unchanged. The main obstacle is a coordinate mismatch: Delft3D-FLOW
uses terrain-following σ-layers whose depth varies in space and time, while OpenDrift expects fixed
z-levels, so the output cannot be read at all without conversion (Ishikawa et al., 2022). We close
this gap with an explicit σ-to-z coupling that also handles the velocity rotation and surface
Stokes-drift derivation needed to make lake hydrodynamics readable by an ocean tracker.

**Table 1.** Positioning of the proposed pipeline relative to existing approaches to lake
transport forcing.

| Existing approach | Limitation for lake transport | This pipeline |
|---|---|---|
| Global ocean reanalyses (CMEMS) to OpenDrift | coverage ends at the coast | forcing for any lake from open data |
| Hand-built per-lake hydrodynamic models | labour-intensive, non-reproducible | auto-generates the setup from open inputs |
| 1-D vertical lake models (e.g., GLM) | no horizontal transport field | full 3-D currents + waves on a grid |
| Site-specific transport frameworks (e.g., CaMPSim-3D) | configured per site and per engine | engine output exported to a generic CF reader |
| Tracker native readers (e.g., ROMS-format, generic CF) | no Delft3D reader available; σ-fields not directly ingestible | σ-to-z coupling bridges the gap |
| GLOBathy / HydroLAKES | static bathymetry only | adds physics-based currents + waves |
| Idealised / analytical lake flow | no data, no waves/Stokes, no heat | data-driven FLOW+WAVE + Stokes |

The contributions are twofold. The computational one is the σ-to-z coupling and the automated
engine-to-tracker framework around it — the σ-layer reconstruction with velocity rotation, regridding
and Stokes-drift derivation, plus automated generation of closed-lake Delft3D models from open inputs.
The geoscientific one is to remove the forcing bottleneck that has kept Lagrangian transport modelling
out of reach for most inland waters, shown by running one unchanged toolchain on twelve diverse lakes
across all inhabited continents. Section 2 gives the coupling and its equations; Section 3 the
software; Section 4 the application; Section 5 the results; Sections 6–7 limitations and conclusions.

---

## 2. Theory and methods

This section gives the workflow (2.1), grid (2.2), forcing (2.3), closed-lake setup (2.4), σ-to-z
coupling (2.5) and transport demonstration (2.6); the relations shown are those in the released code.

### 2.1 Pipeline overview

The pipeline (Fig. 1) is a chain of small Python modules linked through files, not shared memory, so
each stage runs, is inspected or replaced on its own and any failure stays local. Five stages run in
turn: grid construction (bathymetry → the grid triple `.grd`/`.dep`/`.enc`); meteorological forcing
(ERA5 → wind, heat and evaporation–precipitation series); model generation (grid + forcing → the FLOW
`.mdf` and WAVE/SWAN `.mdw`); coupled simulation (Delft3D-FLOW + WAVE/SWAN → σ-coordinate currents,
water level, temperature and waves); and export (Section 2.5 → one CF NetCDF, optionally with the
OpenDrift demonstration). The closed-lake case runs start to finish without hand input — editing
control files by hand is the most error-prone step — and because every file is standard, a user can
inspect, override or swap in an external product. The exporter uses only the engine output, so it also
works on Delft3D models the pipeline did not build (Section 3.2).

[[FIG:architecture]]

### 2.2 Grid construction

Grid construction maps bathymetry onto a Delft3D curvilinear grid and is the only stage whose inputs
differ between lakes. Bathymetry enters either as per-depth shoreline contours from a KMZ file, read
into a `(lon, lat, depth)` point cloud, or as a bed-elevation raster (DAHITI- or GLOBathy-derived
GeoTIFF) read with windowed, decimated I/O so memory stays bounded. Points are projected to the UTM
zone of the lake centroid, and a grid is laid over the bounding box at a cell size scaled to the
basin's longer axis, so lakes of very different size get a similar cell count (tens of metres for
kilometre-scale basins, coarser for the largest). Bed depth is interpolated onto the nodes; for
rasters the still-water depth is `surface_level − bed_elevation` (positive down, per Delft3D). Nodes
outside the shoreline are flagged dry in the `.enc` file. The grid is built counter-clockwise: FLOW
accepts either handedness but SWAN needs counter-clockwise, so one grid drives both engines and avoids
a grid-to-grid interpolation step and orientation-mismatch errors.

### 2.3 Meteorological forcing

Three modules pull ERA5 hourly fields (Hersbach et al., 2020) at the lake centroid and write the
three Delft3D-FLOW time-series files. For wind, the speed is the magnitude of the 10 m components
`u10`, `v10`,

[[EQ:windspeed]]

and the direction is put in the nautical ("blowing-from") convention Delft3D needs,

[[EQ:winddir]]

where the four-quadrant arctangent of the negated components gives the meteorological bearing, modulo
360°. The heat-flux module feeds the Ocean heat-flux model (model 5)
with relative humidity, 2 m air temperature, cloud cover and net shortwave radiation; since ERA5 gives
dewpoint, humidity is rebuilt from air temperature `Ta` and dewpoint `Td` (°C) as a ratio of
saturation vapour pressures via the Magnus form (Magnus, 1844),

[[EQ:magnus]]

with `a = 17.625`, `b = 243.04` °C (Alduchov and Eskridge, 1996), whose vapour-pressure error is
below 0.4 % over −40 to +50 °C. The third module writes precipitation, evaporation and rain
temperature to close the water balance. All series start at the model epoch in local time (the reader
rejects negative times). Because the query is at the centroid, each lake gets a spatially uniform
forcing — fine for small-to-medium basins but a limit at the largest fetch scales (Section 6).

### 2.4 Automated closed-lake model generation

For a closed lake — no open boundaries or discharges — the FLOW problem is fixed by the grid, the
forcing and a few physical defaults (Table 2), so the generator builds a complete configuration with
no hand input. FLOW solves the shallow-water Boussinesq equations on the σ-grid (Lesser et al., 2004),
and SWAN computes third-generation spectral waves in Delft3D-WAVE (Booij et al., 1999) on the shared
grid. The defaults (Table 2) include the Ocean heat-flux model, k–ε mixing (Umlauf and Burchard,
2003), 14 surface-refined σ-layers, the evaporation–precipitation balance, a latitude-derived Coriolis
parameter and a freshwater density reference. Because these and the file wiring are coded into the
generators, adding a lake needs no manual editing of control files — the most error-prone step — while
every default can be overridden.

**Table 2.** Principal physical defaults of the automated closed-lake configuration.

| Parameter | Value | Rationale |
|---|---|---|
| Vertical layers | 14 σ-layers, surface-refined | resolve surface shear for floating tracers |
| Turbulence closure | k–ε (Umlauf and Burchard, 2003) | standard two-equation closure |
| Heat flux | Ocean model (Delft3D model 5) | data-driven air–water exchange |
| Dalton number; Stanton number | 0.0013; 0.0013 | bulk latent; sensible transfer |
| Density reference | freshwater (salinity 0) | inland lakes |
| Coriolis | f from lake latitude | basin-scale rotation |
| Waves | SWAN 3rd-gen, quadruplets on | wind-sea growth |
| Open boundaries | none (closed lake) | common inland case |

### 2.5 The σ-layer to z-level coupling

This coupling makes terrain-following Delft3D output readable by a fixed-depth reader. Delft3D-FLOW
stores its variables on σ-layers — layer k fixed at a fraction σ_{k} of the column thickness, so its
depth changes with the free surface ζ and bed depth d (Fig. 2a) — while OpenDrift expects fixed
z-levels (Fig. 2b). The fields cannot be read at all without conversion, and since the vertical
coordinate strongly affects lake transport (Ishikawa et al., 2022), the geometry is computed exactly
(Eq. 4) before linear interpolation in depth. The export does four steps.

[[FIG:sigma_schematic]]

(1) Vertical reconstruction. For each wet cell and time, the depth of every σ-centre comes from the
water level ζ and bed depth d, with H = ζ + d:

[[EQ:sigmaz]]

with σ_{k} = 0 at the surface and −1 at the bed, read from the `SIG_LYR` variable of the `trim-*.nc`
file (with `S1`, `DPS`, `ALFAS`); a sign check handles builds that store σ positive-down. Fields are
then linearly interpolated onto the fixed set {0, −1, −2, −3, −5, −7.5, −10, −15, −20, −30, −50} m,
clamped to the top layer at z = 0 and masked below the bed. The set is surface-focused, so effective
resolution depends on depth — deep basins fill all eleven levels, the shallowest (~6 m) only four to
five — and is a single parameter (`Z_LEVELS`) changeable for deeper uses.

(2) Velocity rotation. Delft3D returns velocity as grid-aligned (ξ, η) components on a staggered grid;
these are moved to cell centres and rotated to eastward/northward axes through the local grid angle α,
which OpenDrift needs:

[[EQ:rotation]]

The rotation is per cell, since α varies across the basin and one global rotation would misalign the
currents.

(3) Horizontal regridding. Cell centres are projected from UTM to longitude/latitude and the rotated
fields interpolated onto a regular lon–lat raster — the only form the generic reader accepts — with
inactive cells masked first.

(4) Surface Stokes drift. The drift is built from named SWAN fields of the `wavm-*.nc` file: H_{s}
from `HSIGN`, peak period T_{p} from `RTP` (the spectral-peak period, not a mean like `TM01`/`TMM10`),
and direction from `DIR` — naming these avoids the main ambiguity in Eq. (6), since a mean period
would bias the magnitude twofold. A deep-water monochromatic approximation gives the surface magnitude
(Breivik et al., 2014; van den Bremer and Breivik, 2018):

[[EQ:stokes]]

through ω = 2π/T_{p}, k = ω²/g and amplitude a = H_{s}/(2√2), preserving the surface-elevation variance
H_{s}²/8. It is guarded near the wet/dry edge and split into eastward/northward parts. The deep-water
relation weakens for the short wind-seas of the shallowest basins (~6 m), where it affects near-shore
transport (Espenes et al., 2024); the finite-depth relation ω² = gk·tanh(kh), or a spectral profile
(Breivik et al., 2016), is a drop-in fix (Section 6).

The four steps give one CF-1.8 NetCDF with the currents, water level, temperature, wave parameters and
surface Stokes drift on fixed z-levels in longitude/latitude, every variable tagged with a CF
`standard_name` and udunits `units`, so it drives any CF-aware tracker unchanged. Figure 3 shows the
depth-resolved product for one lake (warming and shear kept, sub-bed levels masked) and Figure 4 the
surface fields.

Both interpolations are linear, so the export is not volume-conserving; this is fine because OpenDrift
moves particles kinematically and needs no divergence-free field, unlike an Eulerian solver. Across the
full depth range the median transport error is small and does not grow as the basin shoals (~0.5–2.1 %
from ~6 m to ~40 m basins); the per-column mean is larger (up to ~10 %) but is dominated by the slowest
cells, where a relative measure is ill-conditioned. Users coupling the fields to a conservative
Eulerian scheme should re-derive transports on the native grid.

[[FIG:vertical]]

[[FIG:forcing]]

### 2.6 Transport demonstration setup

To test the exported forcing, a thin driver seeds floating particles and moves them with OpenDrift
(Dagestad et al., 2018) on the CF-NetCDF of Section 2.5. Two changes adapt the ocean tracker to a
lake: OpenDrift's global coastline mask — which would treat the lake interior as land and strand every
particle — is turned off and replaced by an all-water mask, so stranding follows the forcing's data
coverage. The release point is chosen automatically: because the wet-cell centroid can fall on land in
a non-convex basin (crescent Rotsee, bent Balaton), the driver seeds at the pole of inaccessibility,
the interior point farthest from shore, found as the maximum of the Euclidean distance transform of
the water mask (Maurer et al., 2003); its value D_{shore} is the distance to the nearest dry cell. The
release radius is scaled to the basin so the seed disk stays inside it,

[[EQ:radius]]

with the cap r_{max} = 300 m for large lakes and 0.6 D_{shore} for small ones (a fixed 300 m radius
overspills the ~2 km Rotsee). The net displacement of each particle after time t is the distance
D_{i} between its position (λ_{i}, φ_{i}) and release point (λ_{0}, φ_{0}),

[[EQ:drift]]

an equirectangular approximation (Snyder, 1987) accurate at kilometre scale; the ensemble is
summarised by the mean of D_{i}.

---

## 3. Software description

This section describes the software of Section 2: the module architecture (3.1) and the implementation
and usage (3.2). Each module does one transformation with explicit file inputs and outputs, so the
toolchain runs end-to-end or is reused piece by piece — in particular the σ-to-z exporter, usable on
any Delft3D-FLOW/WAVE output.

### 3.1 Architecture and modules

The software is a set of single-purpose command-line modules linked through files, so the data flow
of Section 2 maps onto the code (Fig. 1): bathymetry ingestion (`ingest_bathy_kmz.py`,
`dahiti_bathymetry.py`, `gebco_subset.py`) to a common `(lon, lat, depth)` cloud; grid construction
(`build_grid.py`); ERA5 forcing (`get_era5_*.py`); model generation (`make_flow_mdf.py`,
`make_wave_mdw.py`); coupling and transport (`cf_export.py`, `run_opendrift_demo.py`); and
orchestration (`setup_lake.py`, `postprocess_lake.py`) around the external Delft3D run. A separate
tooling layer regenerates every figure, equation and this manuscript from the data, so results and
document are reproducible artefacts of one repository.

### 3.2 Implementation, dependencies and usage

The code is pure Python 3.11 on a small scientific stack (`xarray`, `netCDF4`, `numpy`, `scipy`,
`pyproj`, `rasterio`, `cdsapi`, `matplotlib`, `cartopy`); a pinned `requirements.txt` and a
`Dockerfile`/`environment.yml` make the open part of the workflow reproducible with one command. The
only heavyweight dependency is the engine, Delft3D 4.07.01 (FLOW + WAVE/SWAN), installed separately;
the reported runs used the official Deltares pre-built Windows-x64 binary, so results do not depend on
a local build. The README gives the exact ERA5/CDS dataset and variable names, the Delft3D version and
the credential setup.

A lake is processed with two commands around the engine run — `setup_lake.py` stages the grid, forcing
and model files, and `postprocess_lake.py` runs the σ-to-z export and demonstration — the only per-lake
inputs being location, latitude and a seasonal initial temperature. Because the exporter needs only
engine output, `cf_export.py` can be pointed at any existing Delft3D-FLOW/WAVE model to make
OpenDrift-ready CF-NetCDF. To make it reproducible without the engine, the repository bundles a
checksummed Erken fixture and a continuous-integration test that runs the exporter from a clean
checkout and checks CF compliance.

---

## 4. Illustrative application: twelve lakes

This section shows one unmodified toolchain producing plausible forcing across widely differing
lakes; 4.1 lists the lakes and data sources and 4.2 the common configuration.

### 4.1 Lake selection and data sources

We applied the pipeline to twelve lakes spanning the factors that control lake surface transport
(Fig. 5; Table 3): from 36°S (Eucumbene, Australia) to 60°N (Erken, Sweden), across all inhabited
continents; maximum depth over an order of magnitude (~6 m to the ~80 m Polyfytos) and area over three
orders; and types from shallow floodplain lakes to a deep stratifying basin and several reservoirs.
Both hemispheres are covered, so the fixed July window is Southern-Hemisphere winter for some lakes,
and the set uses both bathymetry paths of Section 2.2 — survey contours and DAHITI altimetry (Schwatke
et al., 2015). Covering this range with identical code is the property under test.

**Table 3.** The twelve demonstration lakes and key model outputs. |U|_{max} = maximum surface
current speed; H_{s,max} = maximum significant wave height. The drift columns give the 36-h mean net
displacement: the single-release current+Stokes case, the five-point release ensemble median
(Section 5.3), and the +2 % windage case (Section 5.2). All lakes are auto-generated from open data
**except Polyfytos** (bold, asterisk), which reuses an expert-built hand-configured model and is the
export-path control (Section 5.6), not an auto-generated case.

| Lake | Country | Regulation | Lat | Max depth (m) | Mean depth (m) | \|U\|_{max} (m/s) | H_{s,max} (m) | Drift, current+Stokes (m) | Drift, ensemble median (m) | Drift, +windage (m) |
|---|---|---|--:|--:|--:|--:|--:|--:|--:|--:|
| Lagdo | Cameroon | reservoir | 8.8 | ~9 | 4.5 | 0.030 | 0.39 | 2439 | 850 | 1970 |
| Bornos | Spain | reservoir | 36.8 | ~20 | 8.0 | 0.028 | 0.21 | 1337 | 2520 | 5166 |
| Mead | USA | reservoir | 36.3 | ~40 | 20.0 | 0.049 | 0.51 | 2933 | 3220 | 8315 |
| **Polyfytos\* (hand-built)** | Greece | reservoir | 40.2 | ~80 | 30.0 | 1.18 | 0.32 | 1743 | 2560 | 5874 |
| Trasimeno | Italy | natural | 43.1 | ~7 | 4.7 | 0.012 | 0.33 | 3419 | 3320 | 2047 |
| Balaton | Hungary | natural | 46.9 | ~9 | 3.2 | 0.005 | 0.36 | 3250 | 2950 | 4854 |
| Rotsee | Switzerland | natural | 47.1 | ~16 | 9.0 | 0.018 | 0.14 | 341 | 260 | 819 |
| Erken | Sweden | natural | 59.8 | ~20 | 9.0 | 0.010 | 0.20 | 2033 | 230 | 3771 |
| Poyang | China | natural | 29.1 | ~6 | 3.0 | 0.020 | 0.41 | 3695 | 3360 | 11179 |
| Sea of Galilee | Israel | natural | 32.8 | ~6† | 3.0 | 0.032 | 0.34 | 3506 | 3480 | 1102 |
| Eucumbene | Australia | reservoir | −36.1 | ~38 | 18.0 | 0.052 | 0.33 | 3166 | 3440 | 9189 |
| Nova Ponte | Brazil | reservoir | −19.1 | ~23 | 11.0 | 0.030 | 0.41 | 2881 | 3470 | 8803 |

\*Polyfytos (bold row) is **not auto-generated**: it reuses an expert-built, hand-configured
Delft3D model that includes river discharges, hence its larger peak currents; the other eleven are
auto-generated closed-lake setups produced by the pipeline from open data alone. †For Sea of
Galilee the value is the DAHITI satellite-observed depth band, not the absolute maximum
depth (Section 6).

[[FIG:map]]

### 4.2 Configuration

All twelve lakes used an identical configuration, so any difference reflects the lakes, not tuning.
The coupled run covered a common two-day window in July 2022, and only three per-lake inputs varied:
location (grid and meteorological query), latitude (Coriolis) and a seasonal initial water temperature.
Eleven models were built fully automatically; the twelfth, Polyfytos, reused an existing hand-built
model with river discharges (Papaioannou et al., 2025) as a control that isolates the export path from
model generation — counted once, not an extra case. In each lake 400 particles were released at the
interior point of Section 2.6. The model runs 48 h; the first 12 h are discarded as spin-up and
transport integrated over the final 36 h, so the statistics are a forced near-surface response, not a
long-term equilibrium.

---

## 5. Results and discussion

The twelve runs are analysed for internally coherent, physically ordered forcing (5.1–5.3), quality
control (5.4), relation to existing tools (5.5) and two reference comparisons (5.6, 5.7). No parameter
was tuned per lake.

### 5.1 Circulation, temperature and waves

Across all twelve lakes the pipeline gives coherent wind- and heat-driven circulation (Figs. 4, 6),
despite an order-of-magnitude spread in depth, three orders in area and 96° of latitude. Wind stress
drives basin-scale patterns — along-wind drift with return flow, gyres in enclosed basins. Surface
speeds range from a few mm s⁻¹ in sheltered lakes to ~1.2 m s⁻¹ in the river-fed Polyfytos control;
the auto-generated lakes reach 0.5–5 cm s⁻¹, a few percent of the wind. The depth-resolved export
(Fig. 3) shows surface-intensified currents decaying several-fold to ~20 m. Surface temperatures
track the seasonal heat forcing in both hemispheres, from 2–10 °C in winter Eucumbene to 26–35 °C in
the tropical and Mediterranean lakes; over 48 h from an isothermal start this is developing warming,
not an equilibrium thermocline (Section 6). The wind-sea is fetch-limited everywhere (H_{s} =
0.14–0.51 m), largest on the long-fetch reservoirs (Mead) and smallest in sheltered Rotsee.

### 5.2 Surface transport

Figure 6 overlays each lake's mean surface current with the 36-h trajectories of the 400 particles.
Trajectories stay within the basin in every case — confirming the all-water landmask of Section 2.6 —
and spread into wind-aligned plumes. The 36-h mean net displacement D_{i} spans an order of magnitude,
from 0.34 km in the small, deep Rotsee to 3.7 km in the large, shallow Poyang (Table 3). Because every
lake ran through the same unmodified code — eleven also auto-configured from open data — this range
comes from the lakes' own physics, the central generalisation claim.

For floating litter that also feels wind drag (surface-trapped and water-column transport differ in
plastic fate; Oswald et al., 2025) we re-ran each lake with a 2 % windage (the standard leeway;
Breivik et al., 2011; Table 3). Windage is not simply additive: the uniform ERA5 wind adds a
near-uniform shift whose effect depends on its alignment with the drift, amplifying it where they
agree (Poyang 3.7→11.2 km, Eucumbene 3.2→9.2 km) and reducing it where they oppose (Sea of Galilee
3.5→1.1 km, Trasimeno 3.4→2.0 km). Windage thus usually dominates floating-material displacement, as
in marine-debris studies (Chenillat et al., 2021; Tramoy et al., 2020), while currents and Stokes set
the spatial pattern.

[[FIG:demonstration]]

### 5.3 Physical consistency

Figure 7 plots the 36-h current+Stokes drift against mean depth and peak current. With twelve lakes
these are rank tendencies (Spearman): drift correlates positively and significantly with area
(ρ = +0.63, p = 0.03), more weakly with fetch (ρ = +0.57), negatively with depth (ρ ≈ −0.55), and not
with wind (ρ = +0.04). Only the area correlation reaches 5 % significance, and it weakens to marginal
(ρ = +0.54, p = 0.09) without the hand-built Polyfytos, so we read it as a tendency, not a law. Depth
is not the sole control (the deep Eucumbene and Mead both drift ~3 km, being large and long-fetch),
and the highest peak current — river-driven Polyfytos — does *not* give the largest drift, so net
transport is set by basin-scale fetch and exposure, not peak current. These directions match observed
morphometric controls on plastic retention (Nava et al., 2023; Chen et al., 2024).

Re-seeding each lake from five interior points keeps the cross-lake ranking (primary vs
ensemble-median ρ = 0.74), though within a lake the drift varies (median IQR ~19 %, more with
sheltered arms — Erken ~0.2 km versus ~2.0 km at its primary seed, both in Table 3). The
single-release result is thus illustrative, not a converged estimate (Section 6).

[[FIG:scatter]]

### 5.4 Quality control

Two checks support the dataset. An automated audit checks each file — monotonic axes, magnitudes in
bounds, masked sub-bed levels, a non-empty wet surface; all twelve passed. It also found one local
artefact: in the shallowest, strongly lit lakes a few near-shore cells reached ~40 °C, because a thin
column over one solar-heated cell has little thermal inertia. A 35 °C cap removes these spikes while
interior temperatures stay realistic; the artefact is limited to thin-cell shorelines and does not
touch currents or waves, so the Table 3 drifts are unaffected. The proper fix — a minimum-depth
wetting–drying threshold in FLOW — needs per-lake tuning that would break the uniform setup and is
left to future work (Section 6).

### 5.5 Relation to existing tools

The contribution is not a new solver but the automation and coupling that turn a community-validated
3-D engine into a forcing generator for a generic tracker, relative to hand-built single-lake studies
(Papaioannou et al., 2025; Ishikawa et al., 2022). Unlike site-specific frameworks such as CaMPSim-3D
(Pilechi et al., 2022), tied to one engine per study, LakeForcing targets a generic CF reader, so the
same forcing and workflow fit any lake. Only the OpenDrift path (1.14.9) is tested; the same files
should drive other CF readers such as Parcels (Delandmeter and van Sebille, 2019) by construction, but
this is left untested. The σ-to-z export has the widest reach, making any existing Delft3D-FLOW/WAVE
model OpenDrift-ready. The results establish physical plausibility and internal consistency, not full
validation against in-situ data — the natural next step.

### 5.6 Consistency check against an expert-built reference model from the same group

To test the automated forcing against an external model, we ran the auto-generated closed-lake
configuration on the exact grid of the peer-reviewed, expert-built Polyfytos model (Papaioannou et
al., 2025) over their shared 54,520-cell wet domain (Fig. 8). This reference is the authors' own
earlier model of the same reservoir, so the comparison is an internal *consistency check*, not
independent validation. That model was validated against local stations and in-situ data; we treat it
as a like-for-like model, not ground truth. It includes river discharges and a calibrated setup; the
auto configuration uses only the standard closed-lake defaults (Table 2).

Where the physics is shared, the 48-h mean surface fields agree closely: temperature to RMSE 0.85 °C
(bias +0.30 °C) and current speed to 1.5 cm s⁻¹ (r = 0.80). The current *direction* agrees poorly
(|ρ| = 0.10), and adding the river discharge does not help (|ρ| ≈ 0.09), so the difference reflects
the calibrated reference's broader configuration, not the inflow alone. The check thus confirms the
auto forcing reproduces the *thermal field* and current *magnitude* but not the current *direction*,
whose only reference here is itself shaped by the hand-built setup. Independent validation of current
direction against drifters or ADCP moorings — the quantity that most governs where particles go — is
the most valuable next step.

The wave field is left out because the reference is a FLOW model; the exporter regrids the FLOW and
SWAN fields independently onto the common raster (Section 2.5), so no extra error arises. The per-lake
cost is dominated by Delft3D (a 236×233×14, 48-h FLOW run takes ~19 min); the σ-to-z export takes a
few minutes (non-vectorised — an implementation limit, not algorithmic, Section 6), so a
small-to-medium lake runs end-to-end in well under an hour.

[[FIG:validation]]

### 5.7 Independent validation against satellite surface temperature

The Section 5.6 check is model-to-model; to test against observations we compared the auto-generated
surface temperature with satellite lake surface water temperature (LSWT). For four lakes — Bornos,
Mead, Trasimeno and the winter reservoir Nova Ponte — a near-cloudless Landsat-8/9 Collection-2
Level-2 thermal overpass (Vermote et al., 2016) falls within two days of the 1–3 July 2022 window.
From each scene we built a clear-water skin-temperature field using the `QA_PIXEL` flags and binned it
onto the model grid, comparing it with the exported temperature at the model's diurnal basin-mean
maximum (near the overpass). No skin-to-bulk correction was applied (~0.2–0.5 K). All four lakes are
auto-generated, so this tests the pipeline's own heat-flux forcing.

The three Northern-Hemisphere summer lakes run ~4–5 °C cold of the satellite skin, whereas the winter
lake matches to within 0.2 °C. This is an initialisation effect, not a heat-flux error: July 2022 was
a severe heatwave, and a surface started from a *climatological* monthly value over 48 h cannot reach
the anomalously warm skin, while the winter lake is reproduced almost exactly — so the temperatures
are correct in regime and the warm offset is an initialisation cost, fixable by initialising from an
observed temperature. The test constrains the basin mean, not fine structure: driven by one uniform
ERA5 column, the modelled field is nearly uniform (SD 0.0–0.6 °C versus 1.2–4.0 °C observed), so where
it develops structure (Bornos, Trasimeno) it matches the observed pattern (r ≈ 0.7), while in
near-uniform Mead it is uninformative.

[[FIG:satellite]]

---

## 6. Limitations and future work

Most limitations are deliberate simplifications that trade completeness for automation. The main one
is the atmospheric forcing: each lake is driven by one ERA5 column at its centroid, so the forcing is
spatially uniform. This is fine for the small-to-medium lakes that dominate the global inventory but
fails on the largest (Great Lakes, Caspian), where wind gradients drive part of the circulation (Li et
al., 2025); ERA5's ~31 km grid also under-resolves the near-shore wind and lake–land breeze (Crosman
and Horel, 2010). Both are fixable through the existing file interface by feeding in a distributed
wind field.

The wave field uses a stationary SWAN solution — fine for slowly varying lake wind-seas but unable to
capture transient growth under a veering storm; a time-varying run is supported at higher cost. The
surface Stokes drift comes from bulk parameters via a deep-water monochromatic approximation (Section
2.5), giving the surface magnitude and direction but not the vertical decay; a spectral or
depth-resolved profile (Breivik et al., 2014, 2016) would represent the near-surface shear better.

Two further limits come from the inputs and configuration. Where bathymetry is DAHITI-derived, the
altimeter's depth band need not reach the true maximum depth, so the grid is conservative in the
deepest parts (clearest for the Sea of Galilee). The freshwater density reference rules out
hypersaline systems (e.g., the Dead Sea) without turning on salinity transport and an equation of
state, both in Delft3D but off by default. Finally, the climatological temperature initialisation makes
the surface run several degrees cold during a heatwave (Section 5.7); starting from an observed
temperature would remove this, and the offset barely affects the 36-h drift.

Together these define a development path: distributed wind, time-varying waves, observed-temperature
initialisation, a salinity equation of state, a minimum-depth treatment, a depth-dependent Stokes
profile, and vectorisation of the exporter (Section 5.6). The natural next steps are validation against
in-situ drifter data and application at scale to a HydroLAKES sub-sample (Lehner and Döll, 2004;
Messager et al., 2016; Verpoorter et al., 2014) to build an openly distributed forcing archive.

---

## 7. Conclusions

We have presented LakeForcing, an open, reproducible pipeline that turns open global data —
HydroLAKES, GLOBathy and DAHITI bathymetry with ERA5 meteorology — into hydrodynamic and wind-wave
forcing for any inland lake, delivered as CF NetCDF that drives OpenDrift unchanged. Its core is a
fully specified σ-to-z coupling which, with the velocity rotation, regridding and Stokes-drift
derivation, resolves the vertical-coordinate mismatch that otherwise blocks terrain-following Delft3D
output from a generic tracker; with automated closed-lake model generation, it turns a
community-validated 3-D engine into a forcing generator and greatly cuts the per-lake setup cost.

Run unchanged across twelve diverse lakes on all inhabited continents (36°S–60°N), the pipeline gives
physically coherent forcing every time: basin-scale wind-driven circulation with realistic shear;
surface temperatures tracking the seasonal heat forcing in both hemispheres (2–35 °C); and
fetch-limited wave heights H_{s} = 0.14–0.51 m. The 36-h drift spans an order of magnitude (0.34 km in
Rotsee to 3.7 km in Poyang) and varies with basin size, fetch and exposure rather than peak current —
the strongest current (Polyfytos) does not give the largest drift — with a significant area
correlation (ρ = +0.63, p = 0.03) that weakens to marginal without Polyfytos, so read as tendencies
consistent with observed lake-plastic retention (Nava et al., 2023; Chen et al., 2024). An audit
confirmed all twelve datasets and a satellite comparison bounded the surface-temperature accuracy.

By removing the forcing bottleneck and releasing the toolchain and dataset openly, the work lowers the
barrier to lake-scale studies of plastics, oil spills, harmful algal blooms and ecological transport,
and gives a reusable σ-to-z bridge for any existing Delft3D lake model. Coupling the forcing to
in-situ observations and scaling toward a HydroLAKES-wide archive (Messager et al., 2016) are the next
steps.

---

## Software availability

| | |
|---|---|
| Software name | LakeForcing |
| Version | v1.2.0 |
| Developers | V. Papaioannou, C. G. E. Anagnostopoulos, A. Moumtzidou, I. Gialampoukidis, S. Vrochidis, I. Kompatsiaris (CERTH-ITI) |
| Contact | Vassilios Papaioannou — vaspapa@iti.gr; CERTH-ITI, 6th km Charilaou-Thermi, 57001 Thessaloniki, Greece |
| Year first available | 2025 |
| Programming language | Python 3.11 |
| Software dependencies | Pinned in `requirements.txt` (conda-forge Python 3.11 recommended): `opendrift==1.14.9`, plus xarray, numpy, scipy, pyproj, rasterio (GDAL/PROJ via conda-forge), netCDF4, cdsapi, matplotlib, cartopy |
| External hydrodynamic engine | Delft3D 4.07.01 (FLOW + WAVE/SWAN), installed separately. Reported runs used the official Deltares pre-built Windows-x64 binary, release tag 4.07.01, from oss.deltares.nl/web/delft3d (no local build; vendor compiler/flags) |
| External data services | ERA5 via `cdsapi` (dataset `reanalysis-era5-single-levels`, `product_type: reanalysis`; variable short-names listed in §3.2 and the README; Copernicus CDS account and `~/.cdsapirc` required); HydroLAKES; GLOBathy; DAHITI |
| Operating systems | Windows 11 (64-bit) for the reported runs; also runs on 64-bit Linux |
| Hardware requirements | Standard workstation; a multi-core CPU is recommended for the Delft3D-FLOW/WAVE runs |
| Optional features | River-discharge open boundary (used in §5.6, configured via `_build_river_config.py`); supported but **not** exercised by the CI test |
| Source-code size | approximately 0.2 MB (excluding generated data) |
| Code versioning system | git |
| Documentation | Repository README (Delft3D version/tag, ERA5/CDS variable names and credential setup, fixture provenance, and the `build_docx.py` manuscript-rebuild command) and the present manuscript |
| Source repository | https://github.com/vaspapa79/LakeForcing |
| Permanent archive | Zenodo (concept DOI, latest version): https://doi.org/10.5281/zenodo.20627160 |
| Reproducible test capsule | A versioned, checksummed Erken subset in `tests/fixtures/` (`trim-erken_mini.nc`, 125×52 grid, 14 σ-layers, 2 time steps, EPSG:32634; `wavm-erken_mini.nc`), built by `tests/build_fixture.py`, runs the σ-to-z exporter via `pytest`/GitHub-Actions CI with no Delft3D install and asserts CF compliance and the headline variables (§3.2); full hydrodynamic runs require the external engine |
| Licence | MIT (source code); CC-BY-4.0 (generated forcing dataset) |
| Availability and cost | Free and open source |

## CRediT authorship contribution statement
**Vassilios Papaioannou:** Conceptualization, Methodology, Software, Validation, Visualization, Writing – original draft.
**Christos G. E. Anagnostopoulos:** Software, Validation, Visualization, Writing – original draft.
**Dimitrios Valsamis:** Writing – original draft, Writing – review & editing, Validation.
**Anastasia Moumtzidou:** Data curation, Writing – review & editing.
**Ilias Gialampoukidis:** Methodology, Writing – review & editing.
**Stefanos Vrochidis:** Supervision, Writing – review & editing.
**Ioannis Kompatsiaris:** Supervision, Project administration, Funding acquisition.

## Declaration of competing interest
The authors declare that they have no known competing financial interests or personal
relationships that could have appeared to influence the work reported in this paper.

## Data availability
The generated twelve-lake forcing dataset (CC-BY-4.0) consists of the twelve exported CF-compliant
NetCDF files (`<lake>_forcing.nc`, one per lake of Table 3; about 0.9 GB uncompressed). It is
distributed as a versioned GitHub release asset of the source repository
(`LakeForcing-OpenDrift_forcing_dataset_v1.0.0.zip`, about 0.7 GB compressed), accompanied by a
manifest (`DATASET_MANIFEST.txt`) that lists each file's size and SHA-256 checksum so that the
contents can be verified against Section 4. Each file is self-describing and interoperable: it
declares the CF-1.8 conventions and carries CF `standard_name` and udunits `units` on every
variable (Section 2.5), so the dataset is readable by any CF-aware tool without accompanying code,
and a citable dataset-level DOI can be minted on request for users who require one distinct from the
software archive. The source code is separately archived on Zenodo at
https://doi.org/10.5281/zenodo.20627160 (concept DOI), which deposits the repository snapshot under
the MIT licence; the forcing dataset, being a large generated product under a different licence
(CC-BY-4.0), is released alongside the code as the GitHub release asset rather than embedded in the
software archive. All input datasets (HydroLAKES, GLOBathy, DAHITI, ERA5) are openly available from
their respective providers.

## Code availability
The source code is openly available at https://github.com/vaspapa79/LakeForcing under the
MIT licence and is archived on Zenodo at https://doi.org/10.5281/zenodo.20627160. A
continuous-integration test on a small bundled Delft3D fixture exercises the σ-to-z exporter
from a clean checkout with no Delft3D installation.

## Funding
This research did not receive any specific grant from funding agencies in the public,
commercial, or not-for-profit sectors. The work was carried out using the existing research
infrastructure of the Information Technologies Institute, Centre for Research and Technology
Hellas (CERTH-ITI).

## Acknowledgements
The authors thank the developers of Delft3D (Deltares) and OpenDrift, and the providers of
the open datasets used here (HydroLAKES, GLOBathy, DAHITI and ERA5). This work was carried
out in the context of the AINature project (Interreg) and the AQUAMON project (Horizon
Europe), which provided the broader research environment within which it developed. The
authors received no direct funding from either project for the work reported here.

## References

Alduchov, O.A., Eskridge, R.E., 1996. Improved Magnus form approximation of saturation vapor pressure. *J. Appl. Meteorol.* 35, 601–609. https://doi.org/10.1175/1520-0450(1996)035<0601:IMFAOS>2.0.CO;2

Booij, N., Ris, R.C., Holthuijsen, L.H., 1999. A third-generation wave model for coastal regions: 1. Model description and validation. *J. Geophys. Res. Oceans* 104(C4), 7649–7666. https://doi.org/10.1029/98JC02622

Breivik, Ø., Allen, A.A., Maisondieu, C., Roth, J.C., 2011. Wind-induced drift of objects at sea: the leeway field method. *Appl. Ocean Res.* 33, 100–109. https://doi.org/10.1016/j.apor.2011.01.005

Breivik, Ø., Janssen, P.A.E.M., Bidlot, J.-R., 2014. Approximate Stokes drift profiles in deep water. *J. Phys. Oceanogr.* 44, 2433–2445. https://doi.org/10.1175/JPO-D-14-0020.1

Breivik, Ø., Bidlot, J.-R., Janssen, P.A.E.M., 2016. A Stokes drift approximation based on the Phillips spectrum. *Ocean Modell.* 100, 49–56. https://doi.org/10.1016/j.ocemod.2016.01.005

Chen, D., Wang, P., Liu, S., Wang, R., Wu, Y., Zhu, A.-X., Deng, C., 2024. Global patterns of lake microplastic pollution: insights from regional human development levels. *Sci. Total Environ.* 954, 176620. https://doi.org/10.1016/j.scitotenv.2024.176620

Chenillat, F., Huck, T., Maes, C., Grima, N., Blanke, B., 2021. Fate of floating plastic debris released along the coasts in a global ocean model. *Mar. Pollut. Bull.* 165, 112116. https://doi.org/10.1016/j.marpolbul.2021.112116

Cózar, A., Echevarría, F., González-Gordillo, J.I., Irigoien, X., Úbeda, B., Hernández-León, S., Palma, Á.T., Navarro, S., García-de-Lomas, J., Ruiz, A., Fernández-de-Puelles, M.L., Duarte, C.M., 2014. Plastic debris in the open ocean. *Proc. Natl. Acad. Sci. USA* 111, 10239–10244. https://doi.org/10.1073/pnas.1314705111

Crosman, E.T., Horel, J.D., 2010. Sea and lake breezes: a review of numerical studies. *Bound.-Layer Meteorol.* 137, 1–29. https://doi.org/10.1007/s10546-010-9517-9

Dagestad, K.-F., Röhrs, J., Breivik, Ø., Ådlandsvik, B., 2018. OpenDrift v1.0: a generic framework for trajectory modelling. *Geosci. Model Dev.* 11, 1405–1420. https://doi.org/10.5194/gmd-11-1405-2018

Delandmeter, P., van Sebille, E., 2019. The Parcels v2.0 Lagrangian framework: new field interpolation schemes. *Geosci. Model Dev.* 12, 3571–3584. https://doi.org/10.5194/gmd-12-3571-2019

Espenes, H., Carrasco, A., Dagestad, K.-F., Christensen, K.H., Drivdal, M., Isachsen, P.E., 2024. Stokes drift in crossing windsea and swell, and its effect on near-shore particle transport in Lofoten, Northern Norway. *Ocean Modell.* 191, 102407. https://doi.org/10.1016/j.ocemod.2024.102407

Free, C.M., Jensen, O.P., Mason, S.A., Eriksen, M., Williamson, N.J., Boldgiv, B., 2014. High-levels of microplastic pollution in a large, remote, mountain lake. *Mar. Pollut. Bull.* 85, 156–163. https://doi.org/10.1016/j.marpolbul.2014.06.001

Hersbach, H., Bell, B., Berrisford, P., Hirahara, S., Horányi, A., Muñoz-Sabater, J., Nicolas, J., Peubey, C., Radu, R., Schepers, D., Simmons, A., Soci, C., Abdalla, S., Abellan, X., Balsamo, G., Bechtold, P., Biavati, G., Bidlot, J., Bonavita, M., De Chiara, G., Dahlgren, P., Dee, D., Diamantakis, M., Dragani, R., Flemming, J., Forbes, R., Fuentes, M., Geer, A., Haimberger, L., Healy, S., Hogan, R.J., Hólm, E., Janisková, M., Keeley, S., Laloyaux, P., Lopez, P., Lupu, C., Radnoti, G., de Rosnay, P., Rozum, I., Vamborg, F., Villaume, S., Thépaut, J.-N., 2020. The ERA5 global reanalysis. *Q. J. R. Meteorol. Soc.* 146, 1999–2049. https://doi.org/10.1002/qj.3803

Hipsey, M.R., Bruce, L.C., Boon, C., Busch, B., Carey, C.C., Hamilton, D.P., Hanson, P.C., Read, J.S., de Sousa, E., Weber, M., Winslow, L.A., 2019. A General Lake Model (GLM 3.0) for linking with high-frequency sensor data. *Geosci. Model Dev.* 12, 473–523. https://doi.org/10.5194/gmd-12-473-2019

Ishikawa, M., Gonzalez, W., Golyjeswski, O., Sales, G., Rigotti, J.A., Bleninger, T., Mannich, M., Lorke, A., 2022. Effects of dimensionality on the performance of hydrodynamic models for stratified lakes and reservoirs. *Geosci. Model Dev.* 15, 2197–2220. https://doi.org/10.5194/gmd-15-2197-2022

Iskandar, M.R., Cordova, M.R., Park, Y.-G., 2022. Pathways and destinations of floating marine plastic debris from 10 major rivers in Java and Bali, Indonesia: a Lagrangian particle tracking perspective. *Mar. Pollut. Bull.* 185, 114331. https://doi.org/10.1016/j.marpolbul.2022.114331

Khazaei, B., Read, L.K., Casali, M., Sampson, K.M., Yates, D.N., 2022. GLOBathy, the global lakes bathymetry dataset. *Sci. Data* 9, 36. https://doi.org/10.1038/s41597-022-01132-9

Kukulka, T., Proskurowski, G., Morét-Ferguson, S., Meyer, D.W., Law, K.L., 2012. The effect of wind mixing on the vertical distribution of buoyant plastic debris. *Geophys. Res. Lett.* 39, L07601. https://doi.org/10.1029/2012GL051116

Lehner, B., Döll, P., 2004. Development and validation of a global database of lakes, reservoirs and wetlands. *J. Hydrol.* 296, 1–22. https://doi.org/10.1016/j.jhydrol.2004.03.028

Lehner, B., Liermann, C.R., Revenga, C., Vörösmarty, C., Fekete, B., Crouzet, P., Döll, P., Endejan, M., Frenken, K., Magome, J., Nilsson, C., Robertson, J.C., Rödel, R., Sindorf, N., Wisser, D., 2011. High-resolution mapping of the world's reservoirs and dams for sustainable river-flow management. *Front. Ecol. Environ.* 9, 494–502. https://doi.org/10.1890/100125

Lesser, G., Roelvink, J., van Kester, J., Stelling, G., 2004. Development and validation of a three-dimensional morphological model. *Coastal Eng.* 51, 883–915. https://doi.org/10.1016/j.coastaleng.2004.07.014

Li, J., Zhang, Y., Li, Y., Ma, K., Wang, Z., Zhang, X., Yi, Y., Lu, P., Gao, Z., Wang, M., 2025. Wind-generated flow modeling and future circulation prediction of lakes under complex wind field — a case study of Qinghai Lake. *Environ. Model. Softw.* 187, 106371. https://doi.org/10.1016/j.envsoft.2025.106371

Magnus, G., 1844. Versuche über die Spannkräfte des Wasserdampfs. *Ann. Phys.* 137, 225–247. https://doi.org/10.1002/andp.18441370202

Maurer, C., Rensheng Qi, Raghavan, V., 2003. A linear time algorithm for computing exact Euclidean distance transforms of binary images in arbitrary dimensions. *IEEE Trans. Pattern Anal. Mach. Intell.* 25, 265–270. https://doi.org/10.1109/TPAMI.2003.1177156

Messager, M.L., Lehner, B., Grill, G., Nedeva, I., Schmitt, O., 2016. Estimating the volume and age of water stored in global lakes (HydroLAKES). *Nat. Commun.* 7, 13603. https://doi.org/10.1038/ncomms13603

Nava, V., Chandra, S., Aherne, J., Alfonso, M.B., Antão-Geraldes, A.M., Attermeyer, K., Bao, R., Bartrons, M., Berger, S.A., Biernaczyk, M., Bissen, R., Brookes, J.D., Brown, D., Cañedo-Argüelles, M., Canle, M., Capelli, C., Carballeira, R., Cereijo, J.L., Chawchai, S., Christensen, S.T., Christoffersen, K.S., de Eyto, E., Delgado, J., Dornan, T.N., Doubek, J.P., Dusaucy, J., Erina, O., Ersoy, Z., Feuchtmayr, H., Frezzotti, M.L., Galafassi, S., Gateuille, D., Gonçalves, V., Grossart, H.-P., Hamilton, D.P., Harris, T.D., Kangur, K., Kankılıç, G.B., Kessler, R., Kiel, C., Krynak, E.M., Leiva-Presa, À., Lepori, F., Matias, M.G., Matsuzaki, S.-I.S., McElarney, Y., Messyasz, B., Mitchell, M., Mlambo, M.C., Motitsoe, S.N., Nandini, S., Orlandi, V., Owens, C., Özkundakci, D., Pinnow, S., Pociecha, A., Raposeiro, P.M., Rõõm, E.-I., Rotta, F., Salmaso, N., Sarma, S.S.S., Sartirana, D., Scordo, F., Sibomana, C., Siewert, D., Stepanowska, K., Tavşanoğlu, Ü.N., Tereshina, M., Thompson, J., Tolotti, M., Valois, A., Verburg, P., Welsh, B., Wesolek, B., Weyhenmeyer, G.A., Wu, N., Zawisza, E., Zink, L., Leoni, B., 2023. Plastic debris in lakes and reservoirs. *Nature* 619, 317–322. https://doi.org/10.1038/s41586-023-06168-4

Onink, V., Wichmann, D., Delandmeter, P., van Sebille, E., 2019. The role of Ekman currents, geostrophy, and Stokes drift in the accumulation of floating microplastic. *J. Geophys. Res. Oceans* 124, 1474–1490. https://doi.org/10.1029/2018JC014547

Oswald, S.B., Ragas, A.M.J., Schoor, M.M., Collas, F.P.L., 2025. Plastic transport in rivers: bridging the gap between surface and water column. *Water Res.* 269, 122768. https://doi.org/10.1016/j.watres.2024.122768

Papaioannou, V., Mantsis, D.F., Anagnostopoulos, C.G., Vlachos, K., Moumtzidou, A., Gialampoukidis, I., Vrochidis, S., Kompatsiaris, I., 2025. Integrated hydrodynamic and atmospheric modelling of Polyfytos Lake for substance dispersion using Delft3D and WRF. *Open J. Civ. Eng.* https://doi.org/10.4236/ojce.2025.152013

Pilechi, A., Mohammadian, A., Murphy, E., 2022. A numerical framework for modeling fate and transport of microplastics in inland and coastal waters (CaMPSim-3D). *Mar. Pollut. Bull.* 184, 114119. https://doi.org/10.1016/j.marpolbul.2022.114119

Schwatke, C., Dettmering, D., Bosch, W., Seitz, F., 2015. DAHITI – an innovative approach for estimating water level time series over inland waters using multi-mission satellite altimetry. *Hydrol. Earth Syst. Sci.* 19, 4345–4364. https://doi.org/10.5194/hess-19-4345-2015

Snyder, J.P., 1987. Map Projections — A Working Manual. *U.S. Geological Survey Professional Paper* 1395. U.S. Government Printing Office, Washington, D.C. https://doi.org/10.3133/pp1395

Tramoy, R., Gasperi, J., Colasse, L., Tassin, B., 2020. Transfer dynamic of macroplastics in estuaries — new insights from the Seine estuary: Part 1. Long-term dynamic based on date-prints on stranded debris. *Mar. Pollut. Bull.* 152, 110894. https://doi.org/10.1016/j.marpolbul.2020.110894

Umlauf, L., Burchard, H., 2003. A generic length-scale equation for geophysical turbulence models. *J. Mar. Res.* 61, 235–265. https://doi.org/10.1357/002224003322005087

van den Bremer, T.S., Breivik, Ø., 2018. Stokes drift. *Phil. Trans. R. Soc. A* 376, 20170104. https://doi.org/10.1098/rsta.2017.0104

van Sebille, E., Aliani, S., Law, K.L., Maximenko, N., Alsina, J.M., Bagaev, A., Bergmann, M., Chapron, B., Chubarenko, I., Cózar, A., Delandmeter, P., Egger, M., Fox-Kemper, B., Garaba, S.P., Goddijn-Murphy, L., Hardesty, B.D., Hoffman, M.J., Isobe, A., Jongedijk, C.E., Kaandorp, M.L.A., Khatmullina, L., Koelmans, A.A., Kukulka, T., Laufkötter, C., Lebreton, L., Lobelle, D., Maes, C., Martinez-Vicente, V., Morales Maqueda, M.A., Poulain-Zarcos, M., Rodríguez, E., Ryan, P.G., Shanks, A.L., Shim, W.J., Suaria, G., Thiel, M., van den Bremer, T.S., Wichmann, D., 2020. The physical oceanography of the transport of floating marine debris. *Environ. Res. Lett.* 15, 023003. https://doi.org/10.1088/1748-9326/ab6d7d

Vermote, E., Justice, C., Claverie, M., Franch, B., 2016. Preliminary analysis of the performance of the Landsat 8/OLI land surface reflectance product. *Remote Sens. Environ.* 185, 46–56. https://doi.org/10.1016/j.rse.2016.04.008

Verpoorter, C., Kutser, T., Seekell, D.A., Tranvik, L.J., 2014. A global inventory of lakes based on high-resolution satellite imagery. *Geophys. Res. Lett.* 41, 6396–6402. https://doi.org/10.1002/2014GL060641

Wagner, M., Scherer, C., Alvarez-Muñoz, D., Brennholt, N., Bourrain, X., Buchinger, S., Fries, E., Grosbois, C., Klasmeier, J., Marti, T., Rodriguez-Mozaz, S., Urbatzka, R., Vethaak, A.D., Winther-Nielsen, M., Reifferscheid, G., 2014. Microplastics in freshwater ecosystems: what we know and what we need to know. *Environ. Sci. Eur.* 26, 12. https://doi.org/10.1186/s12302-014-0012-7

Wüest, A., Lorke, A., 2003. Small-scale hydrodynamics in lakes. *Annu. Rev. Fluid Mech.* 35, 373–412. https://doi.org/10.1146/annurev.fluid.35.101101.161220

Wynne, T.T., Stumpf, R.P., 2015. Spatial and temporal patterns in the seasonal distribution of toxic cyanobacteria in western Lake Erie from 2002–2014. *Toxins* 7, 1649–1663. https://doi.org/10.3390/toxins7051649

Zhou, X., Rowe, M., Liu, Q., Xue, P., 2023. Comparison of Eulerian and Lagrangian transport models for harmful algal bloom forecasts in Lake Erie. *Environ. Model. Softw.* 162, 105641. https://doi.org/10.1016/j.envsoft.2023.105641
