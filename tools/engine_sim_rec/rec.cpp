// Headless recorder for Engine Simulator: loads an engine script, holds it at set rpms on the dyno, on and off
// throttle, and writes what the synthesizer produces to 44.1 kHz mono WAVs.
#include "engine-sim/scripting/include/compiler.h"
#include "engine-sim/include/simulator.h"
#include "engine-sim/include/engine.h"
#include "engine-sim/include/exhaust_system.h"
#include "engine-sim/include/impulse_response.h"
#include "engine-sim/include/units.h"
#include <cstdio>
#include <vector>
#include <string>
#include <fstream>
#include <cmath>

static std::vector<int16_t> readWav(const std::string &path) {
    std::ifstream f(path, std::ios::binary);
    std::vector<int16_t> out;
    if (!f) { fprintf(stderr, "no IR %s\n", path.c_str()); return out; }
    char id[4]; uint32_t sz; f.read(id, 4); f.read((char *)&sz, 4); f.read(id, 4);
    int ch = 1, bits = 16;
    while (f.read(id, 4)) {
        f.read((char *)&sz, 4);
        if (std::string(id, 4) == "fmt ") {
            std::vector<char> b(sz); f.read(b.data(), sz);
            ch = *(uint16_t *)&b[2]; bits = *(uint16_t *)&b[14];
        } else if (std::string(id, 4) == "data") {
            std::vector<char> b(sz); f.read(b.data(), sz);
            int n = sz / (bits / 8) / ch;
            for (int i = 0; i < n; ++i) {
                if (bits == 16) out.push_back(((int16_t *)b.data())[i * ch]);
                else if (bits == 24) { int v = (uint8_t)b[(i*ch)*3] | ((uint8_t)b[(i*ch)*3+1] << 8) | ((int8_t)b[(i*ch)*3+2] << 16); out.push_back((int16_t)(v >> 8)); }
                else if (bits == 32) out.push_back((int16_t)(((float *)b.data())[i * ch] * 32767.0f));
            }
        } else f.seekg(sz + (sz & 1), std::ios::cur);
    }
    return out;
}

static void writeWav(const std::string &path, const std::vector<int16_t> &s) {
    std::ofstream f(path, std::ios::binary);
    uint32_t data = s.size() * 2, riff = 36 + data, fmt = 16, sr = 44100, br = 88200;
    uint16_t pcm = 1, ch = 1, ba = 2, bits = 16;
    f.write("RIFF", 4); f.write((char *)&riff, 4); f.write("WAVEfmt ", 8); f.write((char *)&fmt, 4);
    f.write((char *)&pcm, 2); f.write((char *)&ch, 2); f.write((char *)&sr, 4); f.write((char *)&br, 4);
    f.write((char *)&ba, 2); f.write((char *)&bits, 2); f.write("data", 4); f.write((char *)&data, 4);
    f.write((char *)s.data(), data);
}

// run the sim for t seconds; keep the audio if rec
static void run(Simulator *sim, double t, std::vector<int16_t> *rec) {
    const double dt = 1.0 / 60.0;
    std::vector<int16_t> buf(4096);
    for (double e = 0; e < t; e += dt) {
        sim->startFrame(dt);
        while (sim->simulateStep()) {}
        sim->endFrame();
        sim->synthesizer().waitProcessed();
        int n;
        while ((n = sim->readAudioOutput(4096, buf.data())) > 0) {
            if (rec) rec->insert(rec->end(), buf.begin(), buf.begin() + n);
            if (n < 4096) break;
        }
    }
}

int main(int argc, char **argv) {
    // es_rec <main.mr> <out_prefix> <idle_rpm> <rpm,rpm,...>
    if (argc < 5) { fprintf(stderr, "usage\n"); return 1; }
    es_script::Compiler compiler;
    compiler.initialize();
    if (!compiler.compile(argv[1])) { fprintf(stderr, "compile failed\n"); return 1; }
    auto out = compiler.execute();
    compiler.destroy();
    Engine *engine = out.engine;
    if (!engine) { fprintf(stderr, "no engine\n"); return 1; }
    Vehicle *vehicle = out.vehicle;
    Transmission *trans = out.transmission;
    if (!vehicle) { Vehicle::Parameters p; p.mass = units::mass(1597, units::kg); p.diffRatio = 3.42; p.tireRadius = units::distance(10, units::inch); p.dragCoefficient = 0.25; p.crossSectionArea = 3.3; p.rollingResistance = 2000; vehicle = new Vehicle; vehicle->initialize(p); }
    if (!trans) { static const double g[] = {2.97, 2.07, 1.43, 1.0, 0.84, 0.56}; Transmission::Parameters p; p.GearCount = 6; p.GearRatios = g; p.MaxClutchTorque = units::torque(1000.0, units::ft_lb); trans = new Transmission; trans->initialize(p); }
    Simulator *sim = engine->createSimulator(vehicle, trans);
    engine->calculateDisplacement();
    sim->setSimulationFrequency(engine->getSimulationFrequency());
    auto ap = sim->synthesizer().getAudioParameters();
    ap.inputSampleNoise = (float)engine->getInitialJitter();
    ap.airNoise = (float)engine->getInitialNoise();
    ap.dF_F_mix = (float)engine->getInitialHighFrequencyGain();
    ap.levelerTarget = 16000.0f;          // headroom: no clipping
    sim->synthesizer().setAudioParameters(ap);
    for (int i = 0; i < engine->getExhaustSystemCount(); ++i) {
        ImpulseResponse *r = engine->getExhaustSystem(i)->getImpulseResponse();
        auto ir = readWav(r->getFilename());
        if (!ir.empty()) sim->synthesizer().initializeImpulseResponse(ir.data(), ir.size(), r->getVolume(), i);
    }
    sim->startAudioRenderingThread();
    printf("ENGINE %s  redline %.0f\n", engine->getName().c_str(), units::toRpm(engine->getRedline()));
    // start it: starter, ignition, throttle cracked
    engine->getIgnitionModule()->m_enabled = true;
    sim->m_starterMotor.m_enabled = true;
    engine->setSpeedControl(0.1);
    run(sim, 2.0, nullptr);
    sim->m_starterMotor.m_enabled = false;
    trans->changeGear(-1);                 // neutral
    run(sim, 2.0, nullptr);
    std::string prefix = argv[2];
    // idle, free running
    sim->m_dyno.m_enabled = false;
    engine->setSpeedControl(0.0);
    run(sim, 3.0, nullptr);
    std::vector<int16_t> rec;
    run(sim, 6.0, &rec);
    printf("IDLE rpm %.0f\n", units::toRpm(std::abs(engine->getRpm() / 60.0 * 2 * M_PI)) );
    writeWav(prefix + "_idle.wav", rec);
    // held on the dyno at each rpm: full throttle (on load) and shut (off load, engine braking)
    std::string list = argv[4];
    size_t p0 = 0;
    while (p0 < list.size()) {
        size_t p1 = list.find(',', p0); if (p1 == std::string::npos) p1 = list.size();
        double rpm = atof(list.substr(p0, p1 - p0).c_str());
        p0 = p1 + 1;
        for (int on = 1; on >= 0; --on) {
            sim->m_dyno.m_enabled = true;
            sim->m_dyno.m_hold = true;
            sim->m_dyno.m_rotationSpeed = units::rpm(rpm);
            engine->setSpeedControl(on ? 1.0 : 0.0);
            run(sim, 2.5, nullptr);
            rec.clear();
            run(sim, 6.0, &rec);
            char nm[256];
            snprintf(nm, sizeof nm, "%s_%d_%s.wav", prefix.c_str(), (int)rpm, on ? "on" : "off");
            writeWav(nm, rec);
            printf("%s rpm %.0f samples %zu\n", nm, engine->getRpm(), rec.size());
            fflush(stdout);
        }
    }
    sim->endAudioRenderingThread();
    return 0;
}
