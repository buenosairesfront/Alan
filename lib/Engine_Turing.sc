// Engine_Turing
// u-ma / turing
//
// un cuerpo = seis voces de drone que nunca se apagan:
//   1 torso   : sub grave + latido + respiracion
//   2 cabeza  : coro de formantes (la cabeza canta vocales)
//   3 brazo i : tendon resonante (ruido frotado por resonadores)
//   4 brazo d
//   5 pierna i: hueso / madera grave, friccion de rodilla
//   6 pierna d
//
// cada voz recibe: freq, amp, open (apertura -> filtro),
// tex (flexion -> textura), pan y dist (desde la camara), en (movimiento)
// fx: reverb por distancia + desintegracion (granos) -> limiter

Engine_Turing : CroneEngine {
  var dryBus, wetBus, fx, voices, lvl;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {
    var s = context.server;
    var defs = [\tur_torso, \tur_head, \tur_arm, \tur_arm, \tur_leg, \tur_leg];
    var freqs = [41.2, 330, 165, 165, 82.4, 82.4];
    dryBus = Bus.audio(s, 2);
    wetBus = Bus.audio(s, 2);
    // nivelacion entre voces (medido en amp_out)
    lvl = [0.4, 2.8, 0.13, 0.13, 0.7, 0.7];

    // ---------------------------------------------------------------- torso
    SynthDef(\tur_torso, { |dry, wet, freq = 41.2, amp = 0.5, open = 0.5, tex = 0, pan = 0,
      dist = 0.3, en = 0, hr = 1, breath = 0|
      var f, o, t, e, d, b, sub, sw, body, trig, lub, dub, heart, air, sig;
      f = Lag.kr(freq, 2.5);
      o = Lag.kr(open, 0.4);
      t = Lag.kr(tex, 0.4);
      e = Lag.kr(en, 0.15);
      d = Lag.kr(dist, 0.5);
      b = Lag.kr(breath, 0.15);
      sub = SinOsc.ar(f, 0, 0.55) + SinOsc.ar(f * 2, 0, 0.16);
      // la torsion abre el coro de sierras
      sw = Mix(Saw.ar(f * 2 * [1 - (t * 0.012) - 0.001, 1 + (t * 0.012) + 0.001, 1.5 + (t * 0.006)], [0.3, 0.3, 0.12]));
      body = sub + LPF.ar(sw, (o.linexp(0, 1, 110, 2200) * (1 + (e * 1.5))).clip(60, 12000));
      body = (body * (0.95 + (b * 0.12))).tanh;
      // latido: lub-dub
      trig = Impulse.kr(Lag.kr(hr, 2));
      lub = EnvGen.ar(Env.perc(0.004, 0.22, 1, -5), trig);
      dub = EnvGen.ar(Env.perc(0.004, 0.17, 0.6, -5), TDelay.kr(trig, 0.24));
      heart = LPF.ar(SinOsc.ar(36 + (lub * 50) + (dub * 40)) * (lub + dub), 200) * 0.85;
      // respiracion: aire que entra y sale
      air = BPF.ar(PinkNoise.ar(1), 650 + (b.max(0) * 800), 0.8) * (((b + 1) * 0.5) ** 2) * 0.22;
      sig = (body + heart + air) * amp;
      sig = Pan2.ar(sig, Lag.kr(pan, 0.3) * 0.5);
      Out.ar(dry, sig * (1 - (d * 0.5)));
      Out.ar(wet, sig * (0.1 + (d * 0.8)));
    }).add;

    // ---------------------------------------------------------------- cabeza
    SynthDef(\tur_head, { |dry, wet, freq = 330, amp = 0.5, open = 0.5, tex = 0.2, pan = 0,
      dist = 0.3, en = 0, vowel = 0.5|
      var f, o, t, e, d, v, vib, src, f1, f2, f3, sig;
      f = Lag.kr(freq, 1.8);
      o = Lag.kr(open, 0.4);
      t = Lag.kr(tex, 0.4);
      e = Lag.kr(en, 0.15);
      d = Lag.kr(dist, 0.5);
      v = Lag.kr(vowel, 0.35) * 4;
      vib = 1 + SinOsc.kr(4.8 + (e * 1.5), 0, 0.003 + (e * 0.006)) + LFNoise1.kr(0.3, 0.002);
      src = Mix(Saw.ar(f * vib * [1, 1.0045, 0.9962], 0.33)) + Mix(Saw.ar(f * 0.5 * vib * [1, 1.003], 0.12));
      src = src + (PinkNoise.ar(0.5) * (0.06 + (t * 0.5)));
      // giro de la cabeza = vocal  a e i o u
      f1 = SelectX.kr(v, [800, 400, 290, 450, 325]);
      f2 = SelectX.kr(v, [1150, 1700, 2100, 800, 700]);
      f3 = SelectX.kr(v, [2800, 2600, 2900, 2830, 2530]);
      sig = Mix(BPF.ar(src, [f1, f2, f3] * (0.85 + (o * 0.3)), [0.07, 0.06, 0.05], [1, 0.55, 0.3])) * 3.5;
      sig = sig + (LPF.ar(src, 400) * 0.06);
      sig = sig * amp * (1 + (e * 0.4));
      sig = Pan2.ar(sig, Lag.kr(pan, 0.3));
      Out.ar(dry, sig * (1 - (d * 0.5)));
      Out.ar(wet, sig * (0.1 + (d * 0.8)));
    }).add;

    // ---------------------------------------------------------------- brazo
    SynthDef(\tur_arm, { |dry, wet, freq = 165, amp = 0.5, open = 0.5, tex = 0, pan = 0,
      dist = 0.3, en = 0|
      var f, o, t, e, d, exc, fr, sig;
      f = Lag.kr(freq, 1.5);
      o = Lag.kr(open, 0.4);
      t = Lag.kr(tex, 0.4);
      e = Lag.kr(en, 0.12);
      d = Lag.kr(dist, 0.5);
      // el ruido frota el tendon; moverse lo frota mas fuerte
      exc = (PinkNoise.ar(0.5) * (0.5 + (e * 1.2))) + (Mix(Saw.ar(f * [1, 1.006])) * 0.04);
      exc = LPF.ar(exc, o.linexp(0, 1, 400, 6000));
      // el codo doblado estira los parciales (inarmonico)
      fr = Array.fill(7, { |i| (i + 1) * (1 + (t * 0.013 * i)) });
      sig = DynKlank.ar(`[fr, [1, 0.6, 0.45, 0.3, 0.22, 0.15, 0.1], [2, 1.6, 1.3, 1, 0.8, 0.6, 0.5]], exc, f) * 0.04;
      sig = sig * (1 - (t * 0.3) + (t * 0.3 * SinOsc.kr(5 + (t * 18))));
      sig = LPF.ar(sig, o.linexp(0, 1, 500, 9000)) * amp;
      sig = Pan2.ar(sig, Lag.kr(pan, 0.3));
      Out.ar(dry, sig * (1 - (d * 0.5)));
      Out.ar(wet, sig * (0.1 + (d * 0.8)));
    }).add;

    // ---------------------------------------------------------------- pierna
    SynthDef(\tur_leg, { |dry, wet, freq = 82, amp = 0.5, open = 0.5, tex = 0, pan = 0,
      dist = 0.3, en = 0|
      var f, o, t, e, d, src, sig, grit;
      f = Lag.kr(freq, 2);
      o = Lag.kr(open, 0.4);
      t = Lag.kr(tex, 0.4);
      e = Lag.kr(en, 0.12);
      d = Lag.kr(dist, 0.5);
      src = Mix(Saw.ar(f * [1, 1.004, 0.5], [0.4, 0.4, 0.3]));
      sig = RLPF.ar(src, (o.linexp(0, 1, 80, 1200) * (1 + (e * 1.2))).clip(40, 8000), 0.35);
      // cavidad hueca del hueso
      sig = sig + (BPF.ar(src, f * 3.1, 0.15) * 0.6 * o);
      // rodilla doblada = friccion, crujido
      grit = Mix(Ringz.ar(Dust.ar(15 + (t * 300)) * t, f * [2.31, 3.73, 5.13] * 2, 0.06)) * 0.08;
      sig = ((sig * 0.8) + grit).tanh * amp;
      sig = Pan2.ar(sig, Lag.kr(pan, 0.3));
      Out.ar(dry, sig * (1 - (d * 0.5)));
      Out.ar(wet, sig * (0.1 + (d * 0.8)));
    }).add;

    // ---------------------------------------------------------------- fx
    SynthDef(\tur_fx, { |dry, wet, out, dis = 0, gain = 1, room = 0.5|
      var a, w, rv, sig, ds, gr, cr;
      a = In.ar(dry, 2);
      w = In.ar(wet, 2);
      rv = FreeVerb2.ar(w[0], w[1], 1, 0.75 + (Lag.kr(room, 0.5) * 0.24), 0.45);
      sig = a + (rv * 1.1);
      // desintegracion: el sonido se rompe en granos y chispas
      ds = Lag.kr(dis, 0.2);
      gr = PitchShift.ar(sig, 0.18, 1 + LFNoise1.kr(0.3, ds * 0.05), ds * 0.5, ds * 0.17);
      cr = HPF.ar(Dust2.ar([1, 1] * (ds * 120)), 2000) * ds * 0.25;
      sig = (sig * (1 - (ds * 0.75))) + (gr * ds * 1.4) + cr;
      sig = LeakDC.ar(sig) * gain;
      Out.ar(out, Limiter.ar(sig, 0.9, 0.003));
    }).add;

    s.sync;

    fx = Synth.tail(context.xg, \tur_fx, [\dry, dryBus, \wet, wetBus, \out, context.out_b]);
    voices = defs.collect({ |def, i|
      Synth.before(fx, def, [\dry, dryBus, \wet, wetBus, \freq, freqs[i], \amp, 0])
    });

    // v: voz, freq, amp, open, tex, pan, dist, en
    this.addCommand("v", "ifffffff", { |msg|
      var i = (msg[1].asInteger - 1).clip(0, 5);
      voices[i].set(\freq, msg[2], \amp, msg[3] * lvl[i], \open, msg[4], \tex, msg[5],
        \pan, msg[6], \dist, msg[7], \en, msg[8]);
    });
    this.addCommand("vowel", "f", { |msg| voices[1].set(\vowel, msg[1]) });
    this.addCommand("heart", "ff", { |msg| voices[0].set(\hr, msg[1], \breath, msg[2]) });
    this.addCommand("dis", "f", { |msg| fx.set(\dis, msg[1]) });
    this.addCommand("room", "f", { |msg| fx.set(\room, msg[1]) });
    this.addCommand("gain", "f", { |msg| fx.set(\gain, msg[1]) });
    this.addCommand("lvl", "if", { |msg| lvl[(msg[1].asInteger - 1).clip(0, 5)] = msg[2] });
  }

  free {
    voices.do({ |v| v.free });
    fx.free;
    dryBus.free;
    wetBus.free;
  }
}
