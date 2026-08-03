const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { test } = require("node:test");
const { run, classifyBusiness } = require("../scripts/backfillPublishedBusinesses");

function fakeDoc(id, data) {
  return { id, data: () => data };
}

function fakeDatabase(initial, publicIds = []) {
  const documents = new Map(Object.entries(initial));
  const updates = [];
  const database = {
    updates,
    collection(name) {
      return {
        get: async () => ({
          docs: name === "businesses"
            ? [...documents.entries()].map(([id, data]) => fakeDoc(id, data))
            : [],
        }),
        doc(id) {
          return {
            path: `${name}/${id}`,
            get: async () => ({
              exists: name === "businesses_public"
                ? publicIds.includes(id)
                : documents.has(id),
              data: () => documents.get(id),
            }),
            update: async (values) => {
              updates.push({ id, values });
              documents.set(id, { ...documents.get(id), ...values });
            },
          };
        },
      };
    },
  };
  return database;
}

function tempBackup(name) {
  return path.join(fs.mkdtempSync(path.join(os.tmpdir(), "published-backup-")), name);
}

test("dry-run is default, reports public state, and skips malformed sectors", async () => {
  const database = fakeDatabase({
    vet: { status: "approved", sectors: ["veterinary"] },
    taxi: { status: "approved", sectors: ["pet_taxi"] },
    malformed: { status: "approved", sectors: [] },
  }, ["vet"]);

  const result = await run({ database, argv: [] });
  assert.equal(result.mode, "dry-run");
  assert.equal(result.candidateCount, 2);
  assert.equal(result.skipped.length, 1);
  assert.equal(result.report.find((item) => item.id === "vet").plannedPublished, true);
  assert.equal(result.report.find((item) => item.id === "taxi").plannedPublished, false);
  assert.equal(result.report.find((item) => item.id === "vet").publicExists, true);
  assert.equal(database.updates.length, 0);
});

test("contaminated non-Pet-Taxi candidates are refused before writes", async () => {
  const database = fakeDatabase({
    contaminated: {
      status: "approved",
      sectors: ["veterinary"],
      sectorData: { pet_taxi: { currentLocation: { lat: 41, lng: 29 } } },
    },
  });
  const backup = tempBackup("contaminated.json");

  await assert.rejects(
    run({ database, argv: ["--apply", `--backup-file=${backup}`] }),
    /Refusing to apply/
  );
  assert.equal(database.updates.length, 0);
  assert.equal(fs.existsSync(backup), false);
});

test("apply requires a backup and performs narrow idempotent updates with projection sync", async () => {
  const database = fakeDatabase({
    vet: { status: "approved", sectors: ["veterinary"], profile: { displayName: "Vet" } },
    taxi: { status: "approved", sectors: ["pet_taxi"] },
  });
  const projectionEvents = [];
  const backup = tempBackup("backup.json");

  await assert.rejects(
    run({ database, argv: ["--apply"] }),
    /--apply requires --backup-file/
  );
  assert.equal(database.updates.length, 0);

  const result = await run({
    database,
    argv: ["--apply", `--backup-file=${backup}`],
    synchronizeProjection: async (event) => projectionEvents.push(event),
  });
  assert.equal(result.mode, "apply");
  assert.equal(fs.existsSync(backup), true);
  assert.deepEqual(database.updates.map((item) => item.values), [
    { published: true },
    { published: false },
  ]);
  assert.equal(projectionEvents.length, 2);

  const secondBackup = tempBackup("second.json");
  const second = await run({
    database,
    argv: ["--apply", `--backup-file=${secondBackup}`],
    synchronizeProjection: async () => {
      throw new Error("projection should not run for no-op execution");
    },
  });
  assert.equal(second.candidateCount, 0);
  assert.equal(database.updates.length, 2);
});

test("backup failure occurs before any business write", async () => {
  const database = fakeDatabase({
    vet: { status: "approved", sectors: ["veterinary"] },
  });
  await assert.rejects(
    run({ database, argv: ["--apply", "--backup-file=/dev/null/backup.json"] }),
  );
  assert.equal(database.updates.length, 0);
});

test("classification rejects contamination and plans canonical publication values", () => {
  const database = fakeDatabase({});
  const contaminated = classifyBusiness(
    fakeDoc("contaminated", {
      status: "approved",
      sectors: ["veterinary"],
      sectorData: { pet_taxi: {} },
    }),
    database
  );
  assert.equal(contaminated.contaminationCleanupRequired, true);
  assert.equal(contaminated.plannedPublished, true);
  assert.equal(classifyBusiness(
    fakeDoc("taxi", { status: "approved", sectors: ["pet_taxi"] }),
    database
  ).plannedPublished, false);
});
