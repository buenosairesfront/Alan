-- alan u-ma
-- un cuerpo hecho de datos
-- que suena como un drone
--
-- E1 elegir parte del cuerpo
-- E2 / E3 mover la parte
-- K2 modo camara
--   E1 zoom, E2 orbita, E3 altura
-- K2 mantener: movimiento solo
--   E2 velocidad, E3 cantidad
-- K3 mantener: desintegrar
--
-- K1 mantener:
--   E1 elegir pose (8)
--   K2 guardar / K3 cargar
--   E2 respiracion
--   E3 tonica

engine.name = "Turing"

local W, H = 128, 64
local sin, cos, sqrt, floor, abs = math.sin, math.cos, math.sqrt, math.floor, math.abs
local exp, min, max, random, rad = math.exp, math.min, math.max, math.random, math.rad
local TAU = 2 * math.pi
local DT = 1 / 20
local F = 100               -- focal de la camara (px)
local SCX, SCY = 64, 33     -- centro de pantalla
local TGT = {0, 0.88, 0}    -- la camara mira aca
local DENS = 4100           -- puntos por m2 de silueta

local function clamp(x, a, b) return x < a and a or (x > b and b or x) end

-------------------------------------------------------------------------------
-- articulaciones: id, min, max, reposo, nombre
-------------------------------------------------------------------------------

local J = {
  {"yaw", -80, 80, 0, "cabeza giro"},
  {"nod", -45, 60, 0, "cabeza asentir"},
  {"tfl", -30, 90, 0, "torso flexion"},
  {"twi", -45, 45, 0, "torso torsion"},
}
for _, sd in ipairs({{"L", "izq"}, {"R", "der"}}) do
  local k, n = sd[1], sd[2]
  table.insert(J, {"el" .. k, 0, 180, 8, "hombro " .. n .. " elevacion"})
  table.insert(J, {"pl" .. k, -45, 135, 0, "hombro " .. n .. " plano"})
  table.insert(J, {"ef" .. k, 0, 145, 10, "codo " .. n .. " flexion"})
  table.insert(J, {"er" .. k, -70, 90, 0, "codo " .. n .. " rotacion"})
  table.insert(J, {"hf" .. k, -25, 120, 0, "cadera " .. n .. " flexion"})
  table.insert(J, {"ha" .. k, -20, 50, 4, "cadera " .. n .. " apertura"})
  table.insert(J, {"kn" .. k, 0, 140, 3, "rodilla " .. n})
  table.insert(J, {"an" .. k, -30, 45, 0, "tobillo " .. n})
end
local JI = {}
for _, j in ipairs(J) do JI[j[1]] = j end

-- segmentos del cuerpo (forma en el marco local del hueso)
-- cap: dir, largo, rx0, rz0, rx1, rz1   |   ell: cx, cy, cz, rx, ry, rz
local SHAPES = {
  {"ell", 0, -0.03, 0, 0.165, 0.11, 0.105},      -- 1 pelvis
  {"cap", 1, 0.24, 0.135, 0.095, 0.15, 0.10},     -- 2 abdomen
  {"cap", 1, 0.25, 0.155, 0.105, 0.175, 0.11},    -- 3 pecho
  {"cap", 1, 0.09, 0.05, 0.05, 0.045, 0.045},     -- 4 cuello
  {"ell", 0, 0.11, 0.01, 0.078, 0.112, 0.095},    -- 5 cabeza
  {"ell", 0, 0.095, 0.098, 0.016, 0.026, 0.022},  -- 6 nariz
  {"cap", -1, 0.29, 0.055, 0.055, 0.045, 0.045},  -- 7 brazo izq
  {"cap", -1, 0.26, 0.045, 0.045, 0.035, 0.032},  -- 8 antebrazo izq
  {"ell", 0, -0.08, 0.01, 0.02, 0.085, 0.045},    -- 9 mano izq
  {"cap", -1, 0.29, 0.055, 0.055, 0.045, 0.045},  -- 10 brazo der
  {"cap", -1, 0.26, 0.045, 0.045, 0.035, 0.032},  -- 11 antebrazo der
  {"ell", 0, -0.08, 0.01, 0.02, 0.085, 0.045},    -- 12 mano der
  {"cap", -1, 0.43, 0.085, 0.085, 0.06, 0.06},    -- 13 muslo izq
  {"cap", -1, 0.42, 0.055, 0.058, 0.04, 0.042},   -- 14 pierna izq
  {"ell", 0, -0.045, 0.06, 0.045, 0.035, 0.115},  -- 15 pie izq
  {"cap", -1, 0.43, 0.085, 0.085, 0.06, 0.06},    -- 16 muslo der
  {"cap", -1, 0.42, 0.055, 0.058, 0.04, 0.042},   -- 17 pierna der
  {"ell", 0, -0.045, 0.06, 0.045, 0.035, 0.115},  -- 18 pie der
}
local NSEG = #SHAPES

-- partes que se eligen con E1 (en sentido horario visto de frente)
local PARTS = {
  {a = "yaw", b = "nod", segs = {4, 5, 6}, joint = "neck"},
  {a = "elL", b = "plL", segs = {7, 8, 9}, joint = "shL"},
  {a = "efL", b = "erL", segs = {8, 9}, joint = "ebL"},
  {a = "hfL", b = "haL", segs = {13, 14, 15}, joint = "hpL"},
  {a = "knL", b = "anL", segs = {14, 15}, joint = "kneeL"},
  {a = "knR", b = "anR", segs = {17, 18}, joint = "kneeR"},
  {a = "hfR", b = "haR", segs = {16, 17, 18}, joint = "hpR"},
  {a = "efR", b = "erR", segs = {11, 12}, joint = "ebR"},
  {a = "elR", b = "plR", segs = {10, 11, 12}, joint = "shR"},
  {a = "tfl", b = "twi", segs = {2, 3}, joint = "waist"},
}

-- voces: articulaciones que las mueven
local VOICE_KEYS = {
  {"tfl", "twi"},
  {"yaw", "nod"},
  {"elL", "plL", "efL", "erL"},
  {"elR", "plR", "efR", "erR"},
  {"hfL", "haL", "knL", "anL"},
  {"hfR", "haR", "knR", "anR"},
}

local SCALES = {
  {"dorico", {0, 2, 3, 5, 7, 9, 10}},
  {"eolico", {0, 2, 3, 5, 7, 8, 10}},
  {"frigio", {0, 1, 3, 5, 7, 8, 10}},
  {"lidio", {0, 2, 4, 6, 7, 9, 11}},
  {"pentatonica", {0, 3, 5, 7, 10}},
  {"quintas", {0, 7}},
}

-- poses de fabrica (lo que no figura queda en reposo)
local FACTORY = {
  {yaw = 0, nod = 0, tfl = 0, twi = 0, elL = 6, elR = 6, plL = 0, plR = 0, efL = 5, efR = 5, erL = 0, erR = 0,
    hfL = 0, hfR = 0, haL = 3, haR = 3, knL = 0, knR = 0, anL = 0, anR = 0},
  {elL = 90, elR = 90, efL = 0, efR = 0, haL = 25, haR = 25},
  {elL = 170, elR = 170, efL = 15, efR = 15, nod = -35},
  {tfl = 30, nod = 35, elR = 50, plR = 95, efR = 140, erR = -40, elL = 20, plL = 60, efL = 70, hfL = 15, knL = 20},
  {hfL = 30, knL = 25, hfR = -15, knR = 10, anR = 12, elL = 25, plL = -40, elR = 30, plR = 100, efL = 20, efR = 45, twi = 8},
  {tfl = 75, nod = 40, hfL = 110, hfR = 110, knL = 130, knR = 130, elL = 60, elR = 60, plL = 100, plR = 100,
    efL = 110, efR = 110, anL = 30, anR = 30},
  {yaw = -50, twi = -30, elL = 95, plL = 120, efL = 5, elR = 40, plR = -30, hfR = 60, knR = 80, haL = 15},
}

-------------------------------------------------------------------------------
-- estado
-------------------------------------------------------------------------------

local S = {
  ready = false, t = 0, frame = 0,
  A = {}, T = {}, prevA = {},   -- angulos actuales / objetivo
  part = 1, cam = false, k1 = false, k3 = false,
  slot = 1, morph = nil, idle = 0, flash = 0, selflash = 0, mapt = 99, fadein = 0,
  cy = 0.35, cy_t = 0.35, cp = 0.12, cp_t = 0.12, cd = 2.8, cd_t = 2.8,
  dis = 0, breath = 0, bph = 0, sway = {0, 0, 0},
  en = {0, 0, 0, 0, 0, 0}, entot = 0, q = {0, 0, 0, 0, 0, 0},
  gscroll = 0, gsacc = 0, emacc = 0,
}
local USER = {}   -- poses guardadas por el usuario (slot -> tabla)

for _, j in ipairs(J) do S.A[j[1]] = j[4]; S.T[j[1]] = j[4]; S.prevA[j[1]] = j[4] end

-- movimiento solo: un pulso comun; cada articulacion lo sigue a una proporcion
-- armonica, un poco atrasada respecto de la anterior (ola), lados en contrafase
local MVH = {yaw = 0.5, nod = 1, tfl = 0.5, twi = 0.5, el = 1, pl = 0.5, ef = 1, er = 2,
  hf = 0.5, ha = 1, kn = 1, an = 2}
local MVP = {yaw = 0.3, nod = 0.9, tfl = 0, twi = 0.6, el = 0.4, pl = 0.8, ef = 1.2, er = 1.6,
  hf = 0.2, ha = 0.7, kn = 1.0, an = 1.5}
local MV, GRAB = {ph = 0, dr = 0}, {}
for _, j in ipairs(J) do
  local id = j[1]
  local base, side = id:sub(1, 2), id:sub(3, 3)
  if not MVH[base] then base = id end
  MV[id] = {h = MVH[base], p = MVP[base] + (side == "R" and math.pi or 0) + random() * 0.3,
    dp = random() * TAU}
  GRAB[id] = 99
end

-------------------------------------------------------------------------------
-- matrices 3x3 (fila mayor)
-------------------------------------------------------------------------------

local function mul(a, b)
  return {
    a[1] * b[1] + a[2] * b[4] + a[3] * b[7], a[1] * b[2] + a[2] * b[5] + a[3] * b[8], a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
    a[4] * b[1] + a[5] * b[4] + a[6] * b[7], a[4] * b[2] + a[5] * b[5] + a[6] * b[8], a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
    a[7] * b[1] + a[8] * b[4] + a[9] * b[7], a[7] * b[2] + a[8] * b[5] + a[9] * b[8], a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
  }
end
local function rx(a) local c, s = cos(a), sin(a); return {1, 0, 0, 0, c, -s, 0, s, c} end
local function ry(a) local c, s = cos(a), sin(a); return {c, 0, s, 0, 1, 0, -s, 0, c} end
local function rz(a) local c, s = cos(a), sin(a); return {c, -s, 0, s, c, 0, 0, 0, 1} end
-- rotacion de angulo a alrededor del eje unitario (x, y, z)
local function raxis(x, y, z, a)
  local c, s = cos(a), sin(a)
  local t = 1 - c
  return {
    t * x * x + c, t * x * y - s * z, t * x * z + s * y,
    t * x * y + s * z, t * y * y + c, t * y * z - s * x,
    t * x * z - s * y, t * y * z + s * x, t * z * z + c,
  }
end
local function app(m, x, y, z)
  return {m[1] * x + m[2] * y + m[3] * z, m[4] * x + m[5] * y + m[6] * z, m[7] * x + m[8] * y + m[9] * z}
end
local function add(p, q) return {p[1] + q[1], p[2] + q[2], p[3] + q[3]} end
-- escala los ejes locales x / y / z de un hueso (respiracion)
local function scl(m, sx, sy, sz)
  return {m[1] * sx, m[2] * sy, m[3] * sz, m[4] * sx, m[5] * sy, m[6] * sz, m[7] * sx, m[8] * sy, m[9] * sz}
end

-------------------------------------------------------------------------------
-- esqueleto (cinematica directa)
-------------------------------------------------------------------------------

local SEGR, SEGT = {}, {}   -- rotacion y origen de cada segmento
local JP = {}               -- posiciones de articulaciones en el mundo

local function seg(s, R, P) SEGR[s] = R; SEGT[s] = P end

local function fk()
  local A, b = S.A, S.breath
  local P0 = {S.sway[1], 0.95 + b * 0.004, 0}
  local R0 = mul(ry(S.sway[2]), rz(S.sway[3]))
  seg(1, R0, P0)
  -- columna: el torso se dobla repartido entre cintura y pecho
  local tf, tw = rad(A.tfl), rad(A.twi)
  local w = add(P0, app(R0, 0, 0.06, 0))
  local Rw = mul(R0, mul(ry(tw * 0.5), rx(tf * 0.6)))
  seg(2, Rw, w)
  local c = add(w, app(Rw, 0, 0.24, 0))
  local Rc = mul(Rw, mul(ry(tw * 0.5), rx(tf * 0.4 - b * 0.02)))
  seg(3, scl(Rc, 1 + b * 0.035, 1, 1 + b * 0.07), c)
  local n = add(c, app(Rc, 0, 0.25, 0))
  local yaw, nod = rad(A.yaw), rad(A.nod)
  local Rn = mul(Rc, mul(ry(yaw * 0.4), rx(nod * 0.4)))
  seg(4, Rn, n)
  local h = add(n, app(Rn, 0, 0.09, 0))
  local Rh = mul(Rn, mul(ry(yaw * 0.6), rx(nod * 0.6)))
  seg(5, Rh, h)
  seg(6, Rh, h)
  JP.waist, JP.chest, JP.neck = w, c, n
  JP.chestc = add(c, app(Rc, 0, 0.13, 0.04))
  JP.head = add(h, app(Rh, 0, 0.11, 0.01))
  JP.headf = app(Rh, 0, 0, 1)

  for si = 1, 2 do
    local k = si == 1 and "L" or "R"
    local sd = si == 1 and 1 or -1
    local o = si == 1 and 0 or 3
    -- hombro: E2 eleva el brazo dentro de un plano vertical, E3 gira ese plano
    local sh = add(c, app(Rc, sd * 0.185, 0.215 + b * 0.006, 0))
    local el, pl = rad(A["el" .. k]), rad(A["pl" .. k])
    local hx, hz = sd * cos(pl), sin(pl)
    local Ru = mul(Rc, mul(raxis(-hz, 0, hx, el), ry(sd * rad(A["er" .. k]))))
    seg(7 + o, Ru, sh)
    local eb = add(sh, app(Ru, 0, -0.29, 0))
    local Rf = mul(Ru, rx(-rad(A["ef" .. k])))
    seg(8 + o, Rf, eb)
    local wr = add(eb, app(Rf, 0, -0.26, 0))
    seg(9 + o, mul(Rf, rx(-0.12)), wr)
    JP["sh" .. k], JP["eb" .. k], JP["wr" .. k] = sh, eb, wr
    -- pierna
    local hp = add(P0, app(R0, sd * 0.095, -0.05, 0))
    local Rt = mul(R0, mul(rx(-rad(A["hf" .. k])), rz(sd * rad(A["ha" .. k]))))
    seg(13 + o, Rt, hp)
    local kn = add(hp, app(Rt, 0, -0.43, 0))
    local Rs = mul(Rt, rx(rad(A["kn" .. k])))
    seg(14 + o, Rs, kn)
    local an = add(kn, app(Rs, 0, -0.42, 0))
    seg(15 + o, mul(Rs, rx(-rad(A["an" .. k]))), an)
    JP["hp" .. k], JP["knee" .. k], JP["an" .. k] = hp, kn, an
  end
end

-------------------------------------------------------------------------------
-- nube de puntos
-------------------------------------------------------------------------------

local NP = 0
local PX, PY, PZ, PS, PB, PW, PR, PF, PH = {}, {}, {}, {}, {}, {}, {}, {}, {}
local QX, QY, QZ = {}, {}, {}  -- direccion de dispersion (desintegracion)
local SX, SY = {}, {}          -- ultima posicion en pantalla
local SEG0, SEG1 = {}, {}

local function gen_points()
  NP = 0
  for s, sh in ipairs(SHAPES) do
    SEG0[s] = NP + 1
    local n
    if sh[1] == "cap" then
      n = floor(sh[3] * (sh[4] + sh[6]) * DENS)
    else
      n = floor(math.pi * (sh[5] * sh[6] + sh[6] * sh[7] + sh[5] * sh[7]) / 3 * 1.25 * DENS)
    end
    if s == 6 then n = 22 end
    for _ = 1, n do
      local fringe = random() < 0.15
      local x, y, z, f
      if sh[1] == "cap" then
        local t = random()
        local u = 2 * t - 1
        local prof = sqrt(max(0, 1 - u * u * u * u * u * u * u * u))
        local rxx = (sh[4] + (sh[6] - sh[4]) * t) * prof
        local rzz = (sh[5] + (sh[7] - sh[5]) * t) * prof
        local a = random() * TAU
        local rho = fringe and (1.04 + random() * 0.45) or sqrt(random())
        x, y, z = cos(a) * rho * rxx, sh[2] * t * sh[3], sin(a) * rho * rzz
        f = fringe and 1 or 0
      else
        local u, v, q
        repeat
          u, v, q = random() * 2 - 1, random() * 2 - 1, random() * 2 - 1
        until u * u + v * v + q * q <= 1
        if fringe then
          local l = sqrt(u * u + v * v + q * q) + 1e-6
          local r = (1.04 + random() * 0.45) / l
          u, v, q = u * r, v * r, q * r
        end
        x, y, z = sh[2] + u * sh[5], sh[3] + v * sh[6], sh[4] + q * sh[7]
        f = fringe and 2 or 0
      end
      NP = NP + 1
      PX[NP], PY[NP], PZ[NP] = x, y, z
      PS[NP], PB[NP] = s, (s - 1) * 12
      PW[NP] = fringe and 0.32 or (s == 6 and 1.6 or 1)
      PR[NP] = random()
      PF[NP] = f
      PH[NP] = random(0, 255)
      -- direccion de dispersion: hacia afuera, un poco hacia arriba
      local dx, dy, dz = random() * 2 - 1, random() * 1.6 - 0.5, random() * 2 - 1
      local l = sqrt(dx * dx + dy * dy + dz * dz) + 1e-6
      local m = (0.35 + random() * 1.1) / l
      QX[NP], QY[NP], QZ[NP] = dx * m, dy * m, dz * m
    end
    SEG1[s] = NP
  end
end

-------------------------------------------------------------------------------
-- malla de alambre (anillos + lineas a lo largo de cada segmento)
-------------------------------------------------------------------------------

local WV = {}   -- vertices: {seg, x, y, z, nx, ny, nz}
local WE = {}   -- aristas: pares de indices de vertice
-- copia plana para dibujar rapido (+ proyeccion y brillo de cada vertice por cuadro)
local WA = {nv = 0, ne = 0, S = {}, SEG = {}, PX = {}, PY = {}, PZ = {}, NX = {}, NY = {}, NZ = {},
  EA = {}, EB = {}, X = {}, Y = {}, D = {}}

local function wvert(s, x, y, z, nx, ny, nz)
  local l = sqrt(nx * nx + ny * ny + nz * nz) + 1e-6
  WV[#WV + 1] = {s, x, y, z, nx / l, ny / l, nz / l}
  return #WV
end

local function gen_wire()
  for s, sh in ipairs(SHAPES) do
    local big = (s == 2 or s == 3 or s == 1 or s == 5)
    local nv = big and 8 or (s == 6 and 4 or 6)
    local rings = {}
    if sh[1] == "cap" then
      local nr = max(3, floor(sh[3] / 0.09) + 1)
      for k = 0, nr - 1 do
        local t = 0.05 + 0.9 * k / (nr - 1)
        local u = 2 * t - 1
        local prof = sqrt(max(0, 1 - u * u * u * u * u * u * u * u))
        local rxx = (sh[4] + (sh[6] - sh[4]) * t) * prof
        local rzz = (sh[5] + (sh[7] - sh[5]) * t) * prof
        local ring = {}
        for j = 0, nv - 1 do
          local a = j / nv * TAU
          ring[j + 1] = wvert(s, cos(a) * rxx, sh[2] * t * sh[3], sin(a) * rzz,
            cos(a) / rxx, sh[2] * u * u * u * u * u * u * u * 9, sin(a) / rzz)
        end
        rings[#rings + 1] = ring
      end
    else
      local lats = s == 6 and {0} or {-60, -22, 22, 60}
      for _, la in ipairs(lats) do
        local cl, sl = cos(rad(la)), sin(rad(la))
        local ring = {}
        for j = 0, nv - 1 do
          local a = j / nv * TAU
          local u, v, q = cos(a) * cl, sl, sin(a) * cl
          ring[j + 1] = wvert(s, sh[2] + u * sh[5], sh[3] + v * sh[6], sh[4] + q * sh[7],
            u / sh[5], v / sh[6], q / sh[7])
        end
        rings[#rings + 1] = ring
      end
      if s ~= 6 then
        -- polos: los meridianos se cierran arriba y abajo
        local bot = wvert(s, sh[2], sh[3] - sh[6], sh[4], 0, -1, 0)
        local top = wvert(s, sh[2], sh[3] + sh[6], sh[4], 0, 1, 0)
        for j = 1, nv do
          WE[#WE + 1] = {bot, rings[1][j]}
          WE[#WE + 1] = {rings[#rings][j], top}
        end
      end
    end
    for k, ring in ipairs(rings) do
      for j = 1, nv do
        WE[#WE + 1] = {ring[j], ring[j % nv + 1]}
        if rings[k + 1] then WE[#WE + 1] = {ring[j], rings[k + 1][j]} end
      end
    end
  end
  WA.nv, WA.ne = #WV, #WE
  for k, v in ipairs(WV) do
    WA.SEG[k], WA.S[k] = v[1], (v[1] - 1) * 12
    WA.PX[k], WA.PY[k], WA.PZ[k], WA.NX[k], WA.NY[k], WA.NZ[k] = v[2], v[3], v[4], v[5], v[6], v[7]
  end
  for k, e in ipairs(WE) do WA.EA[k], WA.EB[k] = e[1], e[2] end
end

-------------------------------------------------------------------------------
-- pantalla: densidad -> brillo, trama binaria, particulas
-------------------------------------------------------------------------------

local D, fb, rows, M = {}, {}, {}, {}
for i = 1, W * H do D[i] = 0; fb[i] = 0 end
local MH = 65                     -- alto de la trama (13 filas de 5 px)
for i = 1, W * MH do M[i] = 0 end
local TONE = {}
for k = 0, 600 do TONE[k] = 15 * (1 - exp(-(k / 16) * 0.5)) end
local SINT = {}
for k = 0, 255 do SINT[k] = sin(k / 256 * TAU) end

-- digitos de 3x4
local GLYPH = {
  [0] = {1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1},
  [1] = {0, 1, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0},
}
local GCOLS, GROWS = 32, 13
local CELL = {}

local function set_cell(c, g)
  CELL[c] = g
  local cx, cy = (c % GCOLS) * 4, floor(c / GCOLS) * 5
  local gl = GLYPH[g]
  for yy = 0, 3 do
    for xx = 0, 2 do
      M[(cy + yy) * W + cx + xx + 1] = gl[yy * 3 + xx + 1]
    end
  end
end
for c = 0, GCOLS * GROWS - 1 do set_cell(c, random(0, 1)) end

local function put(x, y, l)
  if x >= 0 and x < W and y >= 0 and y < H then
    local i = y * W + x + 1
    if fb[i] < l then fb[i] = l end
  end
end

local function wline(x0, y0, x1, y1, l)
  -- entera fuera de la pantalla: no se recorre
  if (x0 < -1 and x1 < -1) or (x0 > 129 and x1 > 129) or (y0 < -1 and y1 < -1) or (y0 > 65 and y1 > 65) then
    return
  end
  local dx, dy = x1 - x0, y1 - y0
  local n = floor(max(abs(dx), abs(dy)) + 0.5)
  if n < 1 then n = 1 end
  dx, dy = dx / n, dy / n
  x0, y0 = x0 + 0.5, y0 + 0.5
  local ka, kb = 0, n
  if n > 48 then
    -- linea larga (camara muy cerca): solo el tramo que cae en pantalla
    if dx > 0 then
      ka, kb = max(ka, -x0 / dx), min(kb, (128 - x0) / dx)
    elseif dx < 0 then
      ka, kb = max(ka, (128 - x0) / dx), min(kb, -x0 / dx)
    end
    if dy > 0 then
      ka, kb = max(ka, -y0 / dy), min(kb, (64 - y0) / dy)
    elseif dy < 0 then
      ka, kb = max(ka, (64 - y0) / dy), min(kb, -y0 / dy)
    end
    if ka > kb then return end
    ka, kb = floor(ka), min(n, floor(kb) + 1)
  end
  for k = ka, kb do
    local x, y = floor(x0 + dx * k), floor(y0 + dy * k)
    if x >= 0 and x < 128 and y >= 0 and y < 64 then
      local i = y * 128 + x + 1
      if fb[i] < l then fb[i] = l end
    end
  end
end

local function glyph(x, y, g, l)
  local gl = GLYPH[g]
  for yy = 0, 3 do
    for xx = 0, 2 do
      if gl[yy * 3 + xx + 1] == 1 then put(x + xx, y + yy, l) end
    end
  end
end

local PART = {}   -- particulas libres
local SW = {}     -- peso de brillo por segmento
local CM = {}     -- matriz camara*segmento (12 por segmento)
local V = {1, 0, 0, 0, 1, 0, 0, 0, 1}

-- S.cd negativo = la camara atraveso la figura y la mira desde el otro lado
local function cam_setup()
  S.cdist = abs(S.cd)
  local yaw = S.cy + (S.cd < 0 and math.pi or 0)
  local c, s = cos(yaw), sin(yaw)
  local cp, sp = cos(S.cp), sin(S.cp)
  V = mul({1, 0, 0, 0, cp, -sp, 0, sp, cp}, {c, 0, -s, 0, 1, 0, s, 0, c})
end

-- mundo -> pantalla
local function project(p)
  local q = app(V, p[1] - TGT[1], p[2] - TGT[2], p[3] - TGT[3])
  local depth = S.cdist - q[3]
  if depth < 0.15 then return nil end
  return SCX + F * q[1] / depth, SCY - F * q[2] / depth, depth, q
end

-- mini boceto arriba a la izquierda (vista de frente: la izquierda del cuerpo a la derecha)
local MAPP = {
  head = {9, 4}, neck = {9, 7}, waist = {9, 12}, pelvis = {9, 16},
  shL = {13, 8}, ebL = {14, 13}, wrL = {15, 18}, shR = {5, 8}, ebR = {4, 13}, wrR = {3, 18},
  hpL = {11, 17}, knL = {11, 22}, ftL = {11, 27}, hpR = {7, 17}, knR = {7, 22}, ftR = {7, 27},
}
local MAPL = {
  {"neck", "pelvis"}, {"shR", "shL"}, {"hpR", "hpL"},
  {"shL", "ebL"}, {"ebL", "wrL"}, {"shR", "ebR"}, {"ebR", "wrR"},
  {"hpL", "knL"}, {"knL", "ftL"}, {"hpR", "knR"}, {"knR", "ftR"},
}
-- por parte (orden de PARTS): punto marcado + lineas resaltadas
local MAPSEL = {
  {"head", {}},
  {"shL", {4, 5}}, {"ebL", {5}}, {"hpL", {8, 9}}, {"knL", {9}},
  {"knR", {11}}, {"hpR", {10, 11}}, {"ebR", {7}}, {"shR", {6, 7}},
  {"waist", {1}},
}

local function ring(cx, cy, r, l)
  for k = 0, 15 do
    local a = k / 16 * TAU
    local x, y = floor(cx + cos(a) * r + 0.5), floor(cy + sin(a) * r + 0.5)
    if x >= 0 and x < W and y >= 0 and y < H then
      local i = y * W + x + 1
      if fb[i] < l then fb[i] = l end
    end
  end
end

local function draw_map()
  local a = S.mapt < 1 and 1 or (1 - (S.mapt - 1) / 1.5)
  if a <= 0 or S.cam then return end
  -- oscurece el fondo del boceto para que se lea sobre el cuerpo
  for y = 0, 30 do
    for x = 0, 19 do
      local i = y * W + x + 1
      fb[i] = floor(fb[i] * (1 - a * 0.85))
    end
  end
  local sel = MAPSEL[S.part]
  local hl = {}
  for _, k in ipairs(sel[2]) do hl[k] = true end
  for k, ln in ipairs(MAPL) do
    local p, q = MAPP[ln[1]], MAPP[ln[2]]
    local l = floor((hl[k] and 13 or 4) * a + 0.5)
    if l > 0 then wline(p[1], p[2], q[1], q[2], l) end
  end
  local h = MAPP.head
  ring(h[1], h[2], 2, floor((sel[1] == "head" and 13 or 4) * a + 0.5))
  -- circulo que late en la articulacion elegida
  local j = MAPP[sel[1]]
  local r = sel[1] == "head" and 4 or 2.5
  ring(j[1], j[2], r + S.selflash, floor((12 + 3 * sin(S.t * 6)) * a + 0.5))
end

-- piso: charco de dither bajo los pies (Bayer 4x4 en pantalla, se apaga hacia afuera)
local BAY = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5}
local FLR = 1.5      -- radio del charco (m)
-- el charco se guarda: con la camara quieta se reusa; en movimiento se recalcula
-- cuadro por medio
local FLC = {n = 0, I = {}, L = {}, key = {}, age = 99}
local function floor_dither()
  local key, CI, CL = FLC.key, FLC.I, FLC.L
  local same = key[1] == S.cy and key[2] == S.cp and key[3] == S.cd
    and key[4] == TGT[1] and key[5] == TGT[2] and key[6] == TGT[3]
  FLC.age = FLC.age + 1
  if same or FLC.age < 2 then
    for j = 1, FLC.n do
      local i = CI[j]
      if fb[i] < CL[j] then fb[i] = CL[j] end
    end
    return
  end
  key[1], key[2], key[3], key[4], key[5], key[6] = S.cy, S.cp, S.cd, TGT[1], TGT[2], TGT[3]
  FLC.age = 0
  local cn = 0
  local camd = S.cdist
  local v1, v2, v3, v4, v5, v6, v7, v8, v9 = V[1], V[2], V[3], V[4], V[5], V[6], V[7], V[8], V[9]
  local FY = -0.035
  -- solo la caja que ocupa el charco en pantalla
  local x0, x1, y0, y1 = W, -1, H, -1
  for k = 0, 15 do
    local a = k / 16 * TAU
    local sx, sy = project({cos(a) * FLR, FY, sin(a) * FLR})
    if not sx then x0, x1, y0, y1 = 0, W - 1, 0, H - 1; break end
    if sx < x0 then x0 = sx end
    if sx > x1 then x1 = sx end
    if sy < y0 then y0 = sy end
    if sy > y1 then y1 = sy end
  end
  x0, x1 = max(0, floor(x0)), min(W - 1, floor(x1) + 1)
  y0, y1 = max(0, floor(y0)), min(H - 1, floor(y1) + 1)
  local b = TGT[2] + v8 * camd
  for sy = y0, y1 do
    local v = -(sy + 0.5 - SCY) / F
    local row = sy * W + 1
    local brow = (sy % 4) * 4 + 1
    for sx = x0, x1 do
      -- solo las celdas de la trama que pueden llegar a prenderse (L * L * 7 < 7)
      local bt = BAY[brow + sx % 4]
      if bt < 7 then
        local u = (sx + 0.5 - SCX) / F
        local a = v2 * u + v5 * v - v8
        if a < -1e-4 or a > 1e-4 then
          local t = (FY - b) / a
          if t > 0.2 then
            local qx, qy, qz = t * u, t * v, camd - t
            local wx = TGT[1] + v1 * qx + v4 * qy + v7 * qz
            local wz = TGT[3] + v3 * qx + v6 * qy + v9 * qz
            local L = 1 - sqrt(wx * wx + wz * wz) / FLR
            if L > 0 and L * L * 7 > bt then
              local i = row + sx
              local lv = (L > 0.5) and 3 or 2
              cn = cn + 1
              CI[cn], CL[cn] = i, lv
              if fb[i] < lv then fb[i] = lv end
            end
          end
        end
      end
    end
  end
  FLC.n = cn
end

local BB = {0, W - 2, 0, H - 2}  -- caja ocupada en el cuadro anterior

local function compose()
  for y = BB[3], BB[4] + 1 do
    local r = y * W + 1
    for i = r + BB[1], r + BB[2] + 1 do D[i] = 0 end
  end
  for i = 1, W * H do fb[i] = 0 end
  local bx0, bx1, by0, by1 = W, -1, H, -1
  local camd, t, dis = S.cdist, S.t, S.dis

  -- brillo por segmento: parte elegida, destello al guardar
  for s = 1, NSEG do SW[s] = 1 + S.flash * 0.8 end
  if not S.cam and not S.splash then
    local pulse = 1.55 + 0.25 * sin(t * 6) + S.selflash * 0.8
    for _, s in ipairs(PARTS[S.part].segs) do SW[s] = SW[s] * pulse end
  end

  -- matrices camara * segmento
  for s = 1, NSEG do
    local C = mul(V, SEGR[s])
    local T = SEGT[s]
    local q = app(V, T[1] - TGT[1], T[2] - TGT[2], T[3] - TGT[3])
    local b = (s - 1) * 12
    for k = 1, 9 do CM[b + k] = C[k] end
    CM[b + 10], CM[b + 11], CM[b + 12] = q[1], q[2], q[3]
  end
  local v1, v2, v3, v4, v5, v6, v7, v8, v9 = V[1], V[2], V[3], V[4], V[5], V[6], V[7], V[8], V[9]
  local zc = 2.8 * 2.8
  local tb = floor(t * 2.1 / TAU * 256)
  -- las particulas del cuerpo: tenues dentro de la malla, plenas al desintegrar
  local pvis = 0.3 + 0.7 * min(1, dis * 2.5)
  -- alcanza con la mitad de los puntos (con el doble de peso)
  local pstep = 2
  pvis = pvis * 2
  -- de lejos el cuerpo se vuelve traslucido: se apaga la malla, queda el contorno
  local far = clamp((camd - 2.8) / 1.7, 0, 1)
  local farb = far * 8
  local tb2 = floor(t * 0.6 / TAU * 256)

  for s = 1, NSEG do
    local b = (s - 1) * 12
    local m1, m2, m3, m4, m5, m6 = CM[b + 1], CM[b + 2], CM[b + 3], CM[b + 4], CM[b + 5], CM[b + 6]
    local m7, m8, m9, tx, ty, tz = CM[b + 7], CM[b + 8], CM[b + 9], CM[b + 10], CM[b + 11], CM[b + 12]
    local sw = SW[s]
    for i = SEG0[s], SEG1[s], pstep do
      local x, y, z = PX[i], PY[i], PZ[i]
      local f = PF[i]
      if f > 0 then
        -- halo que respira
        local j = 1 + 0.2 * SINT[(PH[i] + tb) % 256]
        x, z = x * j, z * j
        if f == 2 then y = y * j end
      end
      local cx = m1 * x + m2 * y + m3 * z + tx
      local cy = m4 * x + m5 * y + m6 * z + ty
      local cz = m7 * x + m8 * y + m9 * z + tz
      local w = PW[i] * sw * pvis
      if dis > 0.002 then
        local k = dis * 1.7 - PR[i] * 0.7
        if k > 0 then
          if k > 1 then k = 1 end
          k = k * k
          local wv = SINT[(PH[i] * 7 + tb2) % 256] * 0.12
          local ox, oy, oz = (QX[i] + wv) * k, (QY[i] + 0.2) * k, (QZ[i] - wv) * k
          cx = cx + v1 * ox + v2 * oy + v3 * oz
          cy = cy + v4 * ox + v5 * oy + v6 * oz
          cz = cz + v7 * ox + v8 * oy + v9 * oz
          w = w * (1 - k * 0.3)
        end
      end
      local depth = camd - cz
      if depth > 0.15 then
        local iz = F / depth
        local sx, sy = SCX + cx * iz, SCY - cy * iz
        SX[i], SY[i] = sx, sy
        -- lo cercano brilla mas; compensa el zoom
        w = w * zc / (depth * depth) * (1 + (camd - depth) * 0.35)
        local ix, iy = floor(sx), floor(sy)
        if ix >= 0 and ix < 127 and iy >= 0 and iy < 63 then
          if ix < bx0 then bx0 = ix end
          if ix > bx1 then bx1 = ix end
          if iy < by0 then by0 = iy end
          if iy > by1 then by1 = iy end
          local fx, fy = sx - ix, sy - iy
          local idx = iy * 128 + ix + 1
          local w0 = w * (1 - fy)
          local w1 = w0 * fx
          D[idx] = D[idx] + w0 - w1
          D[idx + 1] = D[idx + 1] + w1
          w0 = w * fy
          w1 = w0 * fx
          idx = idx + 128
          D[idx] = D[idx] + w0 - w1
          D[idx + 1] = D[idx + 1] + w1
        end
      else
        SX[i] = nil
      end
    end
  end

  -- densidad -> brillo, con la trama de 0/1 fluyendo por dentro
  if bx1 < 0 then bx0, bx1, by0, by1 = 0, 0, 0, 0 end
  BB[1], BB[2], BB[3], BB[4] = bx0, bx1, by0, by1
  local sc = S.gscroll
  -- los digitos crecen y se achican con el zoom (escalados desde el centro)
  local ig = max(0.15, S.cdist / 2.8)
  for y = by0, by1 + 1 do
    local row = y * W
    local my = (floor((y - SCY) * ig + SCY + sc) % MH) * W + 1
    for x = bx0 + 1, bx1 + 2 do
      local d = D[row + x]
      local v = 0
      if d > 0.03 then
        local k = floor(d * 16)
        v = TONE[k > 600 and 600 or k]
        if v > 4 and M[my + floor((x - 1 - SCX) * ig + SCX) % W] == 0 then
          local s = (v - 4) / 6
          v = v * (1 - (s > 1 and 1 or s) * 0.6)
        end
        if far > 0 and d > 0.5 then
          local i = row + x
          if (D[i - 1] or 0) < 0.5 or (D[i + 1] or 0) < 0.5 or (D[i - W] or 0) < 0.5 or (D[i + W] or 0) < 0.5 then
            -- borde de la silueta: marcado
            if v < 13 then v = v + (13 - v) * far end
          elseif BAY[(y % 4) * 4 + x % 4 + 1] < farb then
            -- interior: trama de puntos apagados (sin grises bajos)
            v = 0
          end
        end
      end
      fb[row + x] = floor(v + 0.5)
    end
  end

  -- malla de alambre: lo que mira a la camara brilla, lo de atras queda tenue;
  -- al desintegrar se apaga y quedan solo las particulas
  local wa = (1 - min(1, dis * 2.2)) * (1 - far)
  if wa > 0.02 then
    local WS, WSEG, WPX, WPY, WPZ = WA.S, WA.SEG, WA.PX, WA.PY, WA.PZ
    local WNX, WNY, WNZ, EA, EB = WA.NX, WA.NY, WA.NZ, WA.EA, WA.EB
    local WX, WY, WD = WA.X, WA.Y, WA.D
    for k = 1, WA.nv do
      local b = WS[k]
      local x, y, z = WPX[k], WPY[k], WPZ[k]
      local m7, m8, m9 = CM[b + 7], CM[b + 8], CM[b + 9]
      local depth = camd - (m7 * x + m8 * y + m9 * z + CM[b + 12])
      if depth > 0.15 then
        local m1, m2, m3, m4, m5, m6 = CM[b + 1], CM[b + 2], CM[b + 3], CM[b + 4], CM[b + 5], CM[b + 6]
        local iz = F / depth
        WX[k] = SCX + (m1 * x + m2 * y + m3 * z + CM[b + 10]) * iz
        WY[k] = SCY - (m4 * x + m5 * y + m6 * z + CM[b + 11]) * iz
        local nx, ny, nz = WNX[k], WNY[k], WNZ[k]
        local vx, vy, vz = m1 * nx + m2 * ny + m3 * nz, m4 * nx + m5 * ny + m6 * nz, m7 * nx + m8 * ny + m9 * nz
        -- brillo del vertice: frente fuerte, espalda tenue, lo cercano mas
        local f = vz / (sqrt(vx * vx + vy * vy + vz * vz) + 1e-6)
        local l = (f > 0) and (6 + f * 7) or (2.5 + f * 3)
        WD[k] = l * SW[WSEG[k]] * (1 + (camd - depth) * 0.3) * wa
      else
        WX[k] = nil
      end
    end
    for k = 1, WA.ne do
      local a, b = EA[k], EB[k]
      local xa, xb = WX[a], WX[b]
      if xa and xb then
        local l = (WD[a] + WD[b]) * 0.5
        if l >= 0.5 then wline(xa, WY[a], xb, WY[b], floor((l > 15 and 15 or l) + 0.5)) end
      end
    end
  end

  floor_dither()

  -- piso: grilla de puntos
  local fl = S.cam and 5 or 2
  for gx = -4, 4 do
    for gz = -4, 4 do
      local r = sqrt(gx * gx + gz * gz)
      if r <= 4.3 then
        local sx, sy = project({gx * 0.28, -0.035, gz * 0.28})
        if sx then put(floor(sx + 0.5), floor(sy + 0.5), floor(fl * (1.2 - r / 4.3) + 0.5)) end
      end
    end
  end

  -- particulas: digitos sueltos que se desprenden
  for _, p in ipairs(PART) do
    local l = floor(p.l * (p.life / p.max) + 0.5)
    if l > 0 then
      if p.g then glyph(floor(p.x), floor(p.y), p.g, l) else put(floor(p.x), floor(p.y), l) end
    end
  end

  -- articulacion elegida: corchetes que laten alrededor
  if not S.cam and not S.splash and S.dis < 0.3 then
    local jp = JP[PARTS[S.part].joint]
    local sx, sy = project(jp)
    if sx then
      local x, y = floor(sx + 0.5), floor(sy + 0.5)
      local r = 4 + floor(S.selflash * 3 + 0.5)
      local l = floor(12 + 3 * sin(t * 6))
      for _, c in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
        local cx, cy = x + c[1] * r, y + c[2] * r
        for _, o in ipairs({{0, 0}, {-c[1], 0}, {0, -c[2]}}) do
          local px, py = cx + o[1], cy + o[2]
          if px >= 0 and px < W and py >= 0 and py < H then fb[py * W + px + 1] = l end
        end
      end
      put(x, y, 15)
    end
  end

  draw_map()

  -- modo camara: esquinas de visor
  if S.cam then
    for _, c in ipairs({{1, 1, 1, 1}, {126, 1, -1, 1}, {1, 62, 1, -1}, {126, 62, -1, -1}}) do
      for k = 0, 4 do put(c[1] + k * c[3], c[2], 7); put(c[1], c[2] + k * c[4], 7) end
    end
  end

  -- K1: ocho poses
  if S.k1 then
    for k = 1, 8 do
      local x = 64 - 22 + (k - 1) * 6
      local full = USER[k] or FACTORY[k]
      local l = k == S.slot and floor(12 + 3 * sin(t * 8)) or (full and 6 or 2)
      put(x, 60, l); put(x + 1, 60, l); put(x, 61, l); put(x + 1, 61, l)
      if k == S.slot then put(x, 58, 9); put(x + 1, 58, 9) end
    end
  end
end

-- presentacion: primer plano de la cabeza de Alan a la izquierda + ALAN (Helvetica);
-- despues el texto se apaga y la camara se aleja hasta el cuerpo entero
local SPL = {on = false, t = 0, txt = nil, save = nil}

-- antes de la presentacion: la intro U-MA de particulas (la de uma_splash/splash)
local uma_intro = include("lib/uma_splash_particles")
local uma_sound = include("lib/uma_splash") -- base de la intro, maneja el sonido
local INTRO = {on = false, t0 = 0}
local OUTB = {}

-- camara de la presentacion: primer plano de la cara
local function intro_camera()
  SPL.save = {S.cd_t, S.cp_t}
  S.cd, S.cd_t = 0.6, 0.6
  -- de frente a la cara; despues gira hasta su posicion (3/4)
  local hf = JP.headf
  local front = hf and math.atan(hf[1], hf[3]) or 0
  S.cy_t = S.cy + 0.5
  S.cy = front + TAU * floor((S.cy_t - front) / TAU + 0.5)
  S.cp, S.cp_t = (hf and math.asin(clamp(hf[2], -0.9, 0.9)) or 0.05), 0.05
  local h = JP.head
  if h then TGT[1], TGT[2], TGT[3] = h[1], h[2], h[3] end
  cam_setup()
end

local function load_splash()
  if SPL.hold then SPL.hold:stop(); metro.free(SPL.hold.id); SPL.hold = nil end
  local f = io.open(norns.state.path .. "lib/alan_title.bin", "rb")
  if not f then return end
  local data = f:read("*a")
  f:close()
  if #data ~= W * H then return end
  SPL.txt = {}
  for i = 1, #data, 512 do
    local bt = {string.byte(data, i, i + 511)}
    for k = 1, #bt do SPL.txt[i + k - 1] = bt[k] end
  end
  if not SPL.save then intro_camera() end
  S.splash, SPL.on, SPL.t = true, true, 0
end

local function splash_release()
  if SPL.save then S.cd_t, S.cp_t = SPL.save[1], SPL.save[2]; SPL.save = nil end
end

-- cualquier boton o encoder la adelanta al alejamiento
local function skip_splash()
  if INTRO.on then
    INTRO.on = false
    uma_sound.sound_off()
    SPL.t = 3.5
    return true
  end
  if not SPL.on or SPL.t >= 3.5 then return false end
  SPL.t = 3.5
  return true
end

function redraw()
  if not S.ready then return end
  if INTRO.on then
    local e = util.time() - INTRO.t0
    if e < uma_intro.DUR then
      uma_intro.render(e)
      screen.update()
      return
    end
    INTRO.on = false
    SPL.t = 0
  end
  -- la norns limpia la pantalla al terminar de cargar: la cara vuelve al instante
  if SPL.face then
    screen.poke(0, 0, W, H, SPL.face)
    screen.update()
    SPL.face = nil
  end
  compose()
  local out = fb
  if SPL.on then
    local t = SPL.t + DT
    SPL.t = t
    S.idle = 0
    if t < 3.5 then S.cy_t = S.cy_t + DT * 0.06 else splash_release() end
    local ba = 1
    local ta = t < 0.6 and 0 or (t < 1.2 and (t - 0.6) / 0.6 or (t < 3.5 and 1 or max(0, 1 - (t - 3.5) / 0.8)))
    local sh = t < 3.5 and 30 or floor(30 * max(0, 1 - (t - 3.5)) + 0.5)
    local txt = SPL.txt
    for y = 0, H - 1 do
      local r = y * W
      for x = 1, W do
        local sx = x + sh
        local v = sx <= W and floor(fb[r + sx] * ba + 0.5) or 0
        local tv = txt and floor(txt[r + x] * ta + 0.5) or 0
        OUTB[r + x] = v > tv and v or tv
      end
    end
    out = OUTB
    if t >= 4.5 then SPL.on, S.splash = false, false end
  end
  for y = 0, H - 1 do
    local i = y * W + 1
    rows[y + 1] = string.char(table.unpack(out, i, i + W - 1))
  end
  screen.poke(0, 0, W, H, table.concat(rows))
  screen.update()
end

-------------------------------------------------------------------------------
-- particulas
-------------------------------------------------------------------------------

local function emit(n, segs, speed)
  local cx, cy = project(JP.chest or {0, 1.2, 0})
  cx, cy = cx or 64, cy or 30
  for _ = 1, n do
    if #PART >= 150 then return end
    local i
    if segs then
      local s = segs[random(#segs)]
      i = random(SEG0[s], SEG1[s])
    else
      i = random(NP)
    end
    -- se dibuja un punto de cada dos: se toma el que si tiene posicion en pantalla
    local s0 = SEG0[PS[i]]
    i = s0 + 2 * floor((i - s0) / 2)
    local x, y = SX[i], SY[i]
    if x then
      local dx, dy = x - cx, y - cy
      local l = sqrt(dx * dx + dy * dy) + 1
      local v = (speed or 1) * (3 + random() * 9)
      local life = 0.8 + random() * 1.8
      table.insert(PART, {
        x = x, y = y,
        vx = dx / l * v + (random() - 0.5) * 4, vy = dy / l * v * 0.6 - 2 - random() * 3,
        life = life, max = life, l = 6 + random(9),
        g = random() < 0.45 and random(0, 1) or nil,
      })
    end
  end
end

local function step_particles(dt)
  for k = #PART, 1, -1 do
    local p = PART[k]
    p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
    p.life = p.life - dt
    if p.life <= 0 or p.x < -4 or p.x > W + 4 or p.y < -6 or p.y > H + 4 then
      table.remove(PART, k)
    end
  end
end

-------------------------------------------------------------------------------
-- sonido
-------------------------------------------------------------------------------

local function scale_deg(k)
  local sc = SCALES[params:get("escala")][2]
  local n = #sc
  return sc[k % n + 1] + 12 * floor(k / n)
end

-- cuantiza con histeresis para que la nota no titile en el borde
local function quant(v, raw, n)
  raw = clamp(raw, 0, n - 1)
  if abs(raw - S.q[v]) > 0.7 then S.q[v] = floor(raw + 0.5) end
  return S.q[v]
end

local function dev(v)
  local s, A = 0, S.A
  for _, id in ipairs(VOICE_KEYS[v]) do
    local j = JI[id]
    s = s + abs(A[id] - j[4]) / (j[3] - j[2])
  end
  return clamp(s / #VOICE_KEYS[v] * 2.5, 0, 1)
end

local function mtof(m) return 440 * 2 ^ ((m - 69) / 12) end

local function voice_out(v, note, amp, open, tex, anchor)
  local sx, _, depth = project(anchor)
  local pan, dist = 0, 0.5
  if sx then
    pan = clamp((sx - SCX) / 60, -1, 1)
    dist = clamp((depth - 1.3) / 4, 0, 1)
  end
  engine.v(v, mtof(note), amp, clamp(open, 0, 1), clamp(tex, 0, 1), pan, dist, clamp(S.en[v], 0, 1))
end

local function sound()
  local A, root = S.A, params:get("tonica")
  local effort = 0
  for v = 1, 6 do effort = effort + dev(v) end
  effort = effort / 6

  -- torso: sub fijo; doblarse oscurece, la torsion abre el coro
  voice_out(1, root - 12, 0.8, 0.55 - A.tfl / 110, abs(A.twi) / 45, JP.chest)

  -- cabeza: mirar arriba sube la nota, el giro cambia la vocal
  local kh = quant(2, (60 - A.nod) / 105 * 5, 6)
  voice_out(2, root + 24 + scale_deg(kh) - scale_deg(2), 0.4 + dev(2) * 0.4,
    0.45 - A.nod / 110, 0.12 + abs(A.yaw) / 160, JP.head)
  engine.vowel(clamp((A.yaw + 80) / 160, 0, 1))

  -- brazos: altura de la mano = nota, alcance = filtro, codo = textura
  for si = 1, 2 do
    local k = si == 1 and "L" or "R"
    local v = 2 + si
    local sh, wr, c = JP["sh" .. k], JP["wr" .. k], JP.chest
    local dy = wr[2] - sh[2]
    local ka = quant(v, (dy + 0.55) / 1.1 * 8, 9)
    local rx_, rz_ = wr[1] - c[1], wr[3] - c[3]
    local reach = sqrt(rx_ * rx_ + rz_ * rz_)
    voice_out(v, root + 12 + scale_deg(ka), 0.35 + dev(v) * 0.55,
      (reach - 0.12) / 0.55, A["ef" .. k] / 145 * 0.85 + abs(A["er" .. k]) / 90 * 0.15, wr)
  end

  -- piernas: altura del pie = nota, apertura = filtro, rodilla = friccion
  for si = 1, 2 do
    local k = si == 1 and "L" or "R"
    local v = 4 + si
    local dy = JP["an" .. k][2] - JP["hp" .. k][2]
    local kl = quant(v, (dy + 0.85) / 0.8 * 4, 5)
    voice_out(v, root + scale_deg(kl), 0.4 + dev(v) * 0.5,
      0.25 + (A["ha" .. k] + 20) / 70 * 0.5 + max(0, A["hf" .. k]) / 240, A["kn" .. k] / 140, JP["an" .. k])
  end

  -- latido: se acelera con el esfuerzo y el movimiento
  local hr = 0.85 + effort * 1.1 + S.entot * 0.5
  engine.heart(hr, S.breath)
end

-------------------------------------------------------------------------------
-- poses
-------------------------------------------------------------------------------

local function pose_of(slot)
  local src = USER[slot] or FACTORY[slot]
  if not src then return nil end
  local p = {}
  for _, j in ipairs(J) do p[j[1]] = src[j[1]] or j[4] end
  return p
end

local function sync_params()
  for _, j in ipairs(J) do params:set("j_" .. j[1], S.T[j[1]], true) end
end

local function load_pose(slot, dur, quiet)
  local p = pose_of(slot)
  if not p then return end
  local from = {}
  for k, v in pairs(S.T) do from[k] = v end
  S.morph = {from = from, to = p, t = 0, dur = dur or 2.6}
  if not quiet then emit(25) end
end

local function save_pose(slot)
  local p = {}
  for k, v in pairs(S.T) do p[k] = floor(v + 0.5) end
  USER[slot] = p
  tab.save(USER, norns.state.data .. "poses.tab")
  S.flash = 1
end

-------------------------------------------------------------------------------
-- tiempo
-------------------------------------------------------------------------------

local function step(dt)
  S.t = S.t + dt
  -- fundido de entrada del sonido
  if S.fadein < 1 then
    S.fadein = min(1, S.fadein + dt / 4)
    engine.gain(params:get("volumen") * S.fadein * S.fadein)
  end
  S.frame = S.frame + 1
  S.idle = S.idle + dt

  -- morph entre poses
  if S.morph then
    local m = S.morph
    m.t = m.t + dt
    local k = clamp(m.t / m.dur, 0, 1)
    k = k * k * (3 - 2 * k)
    for id, v in pairs(m.to) do S.T[id] = m.from[id] + (v - m.from[id]) * k end
    if m.t >= m.dur then S.morph = nil; sync_params() end
  end

  -- los musculos siguen al objetivo con inercia
  local A, T = S.A, S.T
  local mv = params:get("movimiento")
  local vel = params:get("mov_vel")
  MV.ph = MV.ph + dt * TAU * (0.02 + vel * vel * 0.4)   -- pulso: 50 s .. 2.4 s por ciclo
  MV.dr = MV.dr + dt * TAU * (0.007 + vel * vel * 0.05) -- deriva lenta, nunca igual
  for _, j in ipairs(J) do
    local id = j[1]
    S.prevA[id] = A[id]
    local goal = T[id]
    GRAB[id] = GRAB[id] + dt
    if mv > 0 then
      local m = MV[id]
      -- la parte que tocaste queda en tus manos 2 s y despues vuelve a moverse
      local g = clamp((GRAB[id] - 2) / 2, 0, 1)
      local amp = mv * 0.4 * (j[3] - j[2])
      -- cerca de un limite, el centro se corre para que la oscilacion entre entera
      local c = clamp(goal, j[2] + amp, j[3] - amp)
      local wave = sin(MV.ph * m.h + m.p) * 0.75 + sin(MV.dr + m.dp) * 0.25
      goal = clamp(goal + (c - goal + amp * wave) * g, j[2], j[3])
    end
    A[id] = A[id] + (goal - A[id]) * 0.22
  end

  -- energia de movimiento por voz
  S.entot = 0
  for v = 1, 6 do
    local s = 0
    for _, id in ipairs(VOICE_KEYS[v]) do s = s + abs(A[id] - S.prevA[id]) end
    local inst = s / dt / 110
    S.en[v] = max(S.en[v] * 0.9, min(1, inst))
    S.entot = S.entot + S.en[v]
  end
  S.entot = min(1, S.entot / 2)

  -- respiracion viva
  local bd = params:get("respiracion")
  local effort = 0
  for v = 1, 6 do effort = effort + dev(v) end
  S.bph = S.bph + dt * TAU * (0.17 + effort / 6 * 0.15)
  S.breath = sin(S.bph) * bd
  S.sway[1] = sin(S.t * 0.21) * 0.006 * bd
  S.sway[2] = sin(S.t * 0.13) * 0.03 * bd
  S.sway[3] = sin(S.t * 0.29 + 1) * 0.012 * bd

  -- desintegracion
  local base = params:get("desintegracion")
  if S.k3 then
    S.dis = min(1, S.dis + dt * 0.35)
  else
    S.dis = max(base, S.dis - dt * 0.5)
    if S.dis < base then S.dis = min(base, S.dis + dt * 0.35) end
  end

  -- camara
  if S.idle > 8 and params:get("auto_orbita") == 2 then S.cy_t = S.cy_t + dt * 0.12 end
  -- en la presentacion la camara se acomoda despacio (de frente a 3/4)
  local ce = S.splash and 0.045 or 0.18
  S.cy = S.cy + (S.cy_t - S.cy) * ce
  S.cp = S.cp + (S.cp_t - S.cp) * ce
  S.cd = S.cd + (S.cd_t - S.cd) * 0.15
  -- al acercarse, la camara apunta a la cabeza (lejos: encuadre de siempre)
  local zk = clamp((2.8 - abs(S.cd)) / 2.4, 0, 1)
  zk = zk * zk * (3 - 2 * zk)
  local pc = JP.head or {0, 1.69, 0.01}
  TGT[1], TGT[2], TGT[3] = pc[1] * zk, 0.88 + (pc[2] - 0.88) * zk, pc[3] * zk
  cam_setup()
  fk()

  -- trama binaria: corre hacia abajo y titila con el movimiento
  S.gsacc = S.gsacc + dt * (2 + S.entot * 14 + S.dis * 10)
  while S.gsacc >= 1 do S.gsacc = S.gsacc - 1; S.gscroll = (S.gscroll - 1) % MH end
  for _ = 1, 3 + floor(S.entot * 40) do set_cell(random(0, GCOLS * GROWS - 1), random(0, 1)) end

  -- particulas: base + las que suelta la parte que se mueve
  S.emacc = S.emacc + dt * (4 + S.dis * 140)
  while S.emacc >= 1 do S.emacc = S.emacc - 1; emit(1, nil, 1 + S.dis * 2) end
  for v = 1, 6 do
    if S.en[v] > 0.05 and random() < S.en[v] then
      local segs = ({{2, 3}, {5}, {7, 8, 9}, {10, 11, 12}, {13, 14, 15}, {16, 17, 18}})[v]
      emit(1 + floor(S.en[v] * 3), segs, 1.3)
    end
  end
  step_particles(dt)

  S.flash = max(0, S.flash - dt * 1.5)
  S.selflash = max(0, S.selflash - dt * 2.5)
  S.mapt = S.mapt + dt

  if S.frame % 2 == 0 then
    sound()
    engine.dis(S.dis)
  end
end

-------------------------------------------------------------------------------
-- controles
-------------------------------------------------------------------------------

function key(n, z)
  S.idle = 0
  if z == 1 and skip_splash() then return end
  if n == 1 then S.k1 = (z == 1); return end
  -- K2: tocar = camara (al soltar); mantener: E2 velocidad, E3 cantidad del movimiento solo
  if n == 2 and (S.k2 or (z == 1 and not S.k1)) then
    if z == 1 then
      S.k2, S.k2_turned = true, false
    else
      S.k2 = false
      if not S.k2_turned then S.cam = not S.cam end
    end
    return
  end
  if n == 3 and z == 0 then S.k3 = false; return end
  if z == 0 then return end
  if S.k1 then
    if n == 2 then save_pose(S.slot) elseif n == 3 then load_pose(S.slot) end
    return
  end
  if n == 2 then
    S.cam = not S.cam
  elseif n == 3 then
    S.k3 = true
  end
end

function enc(n, d)
  S.idle = 0
  if skip_splash() then return end
  if S.k2 then
    S.k2_turned = true
    if n == 2 then params:delta("mov_vel", d) elseif n == 3 then params:delta("movimiento", d) end
    return
  end
  if S.k1 then
    if n == 1 then
      -- K1 + E1: el cuerpo va a cada pose mientras se recorren; al soltar K1 queda esa
      local ns = clamp(S.slot + d, 1, 8)
      if ns ~= S.slot then
        S.slot = ns
        load_pose(ns, 1.2, true)
      end
    elseif n == 2 then
      params:delta("respiracion", d)
    else
      params:delta("tonica", d)
    end
    return
  end
  if S.cam then
    if n == 1 then
      S.cd_t = clamp(S.cd_t - d * 0.08, -5.5, 5.5)
    elseif n == 2 then
      S.cy_t = S.cy_t + d * 0.05
    else
      S.cp_t = S.cp_t + d * 0.03   -- vuelta completa, sin limite
    end
    return
  end
  if n == 1 then
    S.part = (S.part - 1 + (d > 0 and 1 or -1)) % #PARTS + 1
    S.mapt = 0
    S.selflash = 1
  else
    local p = PARTS[S.part]
    if S.morph then S.morph = nil; sync_params() end
    local id = n == 2 and p.a or p.b
    GRAB[id] = 0
    params:delta("j_" .. id, d)
  end
end

-------------------------------------------------------------------------------
-- init
-------------------------------------------------------------------------------

-- pose de arranque: la misma que va a tener el primer paso (con el movimiento solo aplicado)
local function settle_pose(mv)
  for _, j in ipairs(J) do
    local id = j[1]
    local goal = S.T[id]
    if mv > 0 then
      local m = MV[id]
      local amp = mv * 0.4 * (j[3] - j[2])
      local c = clamp(goal, j[2] + amp, j[3] - amp)
      local wave = sin(MV.ph * m.h + m.p) * 0.75 + sin(MV.dr + m.dp) * 0.25
      goal = clamp(c + amp * wave, j[2], j[3])
    end
    S.A[id], S.prevA[id] = goal, goal
  end
end

local NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

local function add_params()
  params:add_separator("turing_sep", "alan")
  params:add_number("tonica", "tonica", 28, 52, 40, function(p)
    local v = p:get()
    return NOTE_NAMES[v % 12 + 1] .. (floor(v / 12) - 1)
  end)
  local names = {}
  for i, s in ipairs(SCALES) do names[i] = s[1] end
  params:add_option("escala", "escala", names, 1)
  params:add_control("respiracion", "respiracion", controlspec.new(0, 1, "lin", 0.01, 0.6, ""))
  params:add_control("movimiento", "movimiento solo", controlspec.new(0, 1, "lin", 0.01, 0, ""))
  params:add_control("mov_vel", "movimiento velocidad", controlspec.new(0, 1, "lin", 0.01, 0.3, ""))
  params:add_control("desintegracion", "desintegracion base", controlspec.new(0, 1, "lin", 0.01, 0, ""))
  params:add_option("auto_orbita", "auto orbita", {"no", "si"}, 2)
  params:add_control("espacio", "espacio (reverb)", controlspec.new(0, 1, "lin", 0.01, 0.5, ""))
  params:set_action("espacio", function(v) engine.room(v) end)
  params:add_control("volumen", "volumen", controlspec.new(0, 2, "lin", 0.01, 1, ""))
  params:set_action("volumen", function(v) engine.gain(v * S.fadein * S.fadein) end)

  params:add_group("cuerpo", #J)
  for _, j in ipairs(J) do
    local id = j[1]
    params:add_control("j_" .. id, j[5],
      controlspec.new(j[2], j[3], "lin", 0, j[4], "", 2 / (j[3] - j[2])))
    params:set_action("j_" .. id, function(v) S.T[id] = v end)
  end
end

function init()
  math.randomseed(os.time())
  add_params()
  params:read(norns.state.data .. "turing.pset", true)
  params:bang()
  USER = tab.load(norns.state.data .. "poses.tab") or {}
  -- si el primer cuadro ya preparo la pose, se sigue desde ahi (sin saltos)
  if not SPL.save then settle_pose(params:get("movimiento")) end
  if NP == 0 then gen_points() end
  if WA.nv == 0 then gen_wire() end
  cam_setup()
  fk()
  load_splash()
  uma_sound.sound_on(norns.state.path .. "lib/uma_particles.wav")
  INTRO.on, INTRO.t0 = true, util.time()
  S.ready = true

  S.metro = metro.init(function()
    step(DT)
    -- freno: si el cuadro anterior tardo demasiado, este no se dibuja
    -- (el sonido y los controles siguen), asi no se encolan los encoders
    if S.skip then
      S.skip = false
    else
      local t0 = util.time()
      redraw()
      if util.time() - t0 > 0.045 then S.skip = true end
    end
  end, DT, -1)
  S.metro:start()
end

function cleanup()
  if S.metro then S.metro:stop() end
  params:write(norns.state.data .. "turing.pset")
end

-- acceso desde la REPL
TUR = {S = S, compose = compose, load_pose = load_pose, emit = emit, NP = function() return NP end}

-- al abrir el script: prepara la pose y la camara de la presentacion y
-- deja la pantalla en negro (sin esto, mientras carga el engine se ve el
-- script anterior)
do
  -- el script anterior deja de dibujar
  if metro.metros then
    for i = 1, metro.num_script_metros or 30 do
      local m = metro.metros[i]
      if m then m.event = function() end end
    end
  end
  -- pose guardada (la misma que va a cargar init)
  local mv = 0
  local f = io.open(norns.state.data .. "turing.pset", "r")
  if f then
    for line in f:lines() do
      local id, v = line:match('^"?j_([%w]+)"?:%s*([%-%d%.e]+)')
      if id and JI[id] and tonumber(v) then S.T[id] = tonumber(v) end
      local m = line:match('^"?movimiento"?:%s*([%-%d%.e]+)')
      if m and tonumber(m) then mv = tonumber(m) end
    end
    f:close()
  end
  settle_pose(mv)
  gen_points()
  gen_wire()
  fk()
  intro_camera()
  fk()
  S.ready, SPL.on, SPL.t, S.splash = true, true, 0, true
  redraw()
  S.ready, SPL.on, SPL.t = false, false, 0
  screen.clear()
  screen.update()
  -- mientras carga el engine: pantalla negra (despues arranca la intro U-MA)
  SPL.hold = metro.init(function()
    screen.clear()
    screen.update()
  end, DT, -1)
  if SPL.hold then SPL.hold:start() end
end
