extends SceneTree
const Rules=preload("res://scripts/linked_rules.gd")
const Catalog=preload("res://scripts/catalog.gd")
const ITERATIONS := 2000

func _initialize() -> void:
 Rules.ensure()
 var ids: Array=Catalog.runtime_ids()
 for id in ids:assert(Rules.definition(id)==Rules._build_definition(id))
 var rebuilt: Array[int]=[]
 var cached: Array[int]=[]
 for run in range(5):
  var start:=Time.get_ticks_usec()
  for repeat in range(ITERATIONS):
   for id in ids:Rules._build_definition(id)
  rebuilt.append(Time.get_ticks_usec()-start)
  start=Time.get_ticks_usec()
  for repeat in range(ITERATIONS):
   for id in ids:Rules.definition(id)
  cached.append(Time.get_ticks_usec()-start)
 rebuilt.sort();cached.sort()
 var result: Dictionary={"calls_per_sample":ITERATIONS*ids.size(),"samples":5,"rebuild_median_us":rebuilt[2],"cached_median_us":cached[2],"ratio":float(rebuilt[2])/maxi(cached[2],1)}
 var file:=FileAccess.open("res://test-results/definition_benchmark.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(result,"  "))
 print("DEFINITION_BENCHMARK_PASS ",JSON.stringify(result))
 quit()
