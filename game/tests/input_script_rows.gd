extends RefCounted

const IC1_ROWS: PackedStringArray = [
	"1|sel=[7, 8]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=false|",
	"2|sel=[7, 8]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=false|{\"entity_ids\":[7,8],\"player\":1,\"sequence\":0,\"target\":[20.5,10.5],\"tick\":0,\"type\":\"move\"}",
	"3|sel=[7, 8]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=false|{\"entity_ids\":[7,8],\"player\":1,\"sequence\":1,\"target\":[24.5,8.5],\"tick\":0,\"type\":\"attack_move\"}|refusal=",
	"4|sel=[7, 8]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=false|{\"entity_ids\":[7,8],\"player\":1,\"sequence\":2,\"tick\":0,\"type\":\"stop\"}",
	"5|sel=[7, 8]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=false|{\"entity_ids\":[7,8],\"player\":1,\"sequence\":3,\"target_id\":9,\"tick\":0,\"type\":\"attack\"}",
	"6|sel=[7, 8]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=false|",
	"7|sel=[]|bld=-1|insp=-1|place=|sub=false|am=false|esc=false|menu=false|perf=false|",
	"8|sel=[]|bld=-1|insp=-1|place=|sub=false|am=false|esc=false|menu=false|perf=false|",
	"9|sel=[10]|bld=-1|insp=-1|place=frc_supply_center|sub=true|am=false|esc=true|menu=false|perf=false||refusal=",
	"10|sel=[10]|bld=-1|insp=-1|place=frc_supply_center|sub=true|am=false|esc=true|menu=false|perf=true|",
	"11|sel=[10]|bld=-1|insp=-1|place=frc_supply_center|sub=true|am=false|esc=true|menu=false|perf=true|{\"builder_id\":10,\"building_kind\":\"frc_supply_center\",\"origin\":[36,26],\"player\":1,\"sequence\":4,\"tick\":0,\"type\":\"build\"}",
	"12|sel=[]|bld=12|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=true|{\"building_id\":12,\"player\":1,\"sequence\":5,\"tick\":1,\"type\":\"produce\",\"unit_kind\":\"usa_rifle_infantry\"}|refusal=",
	"13|sel=[]|bld=12|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=true|{\"building_id\":12,\"player\":1,\"sequence\":6,\"target\":[26.5,16.5],\"tick\":1,\"type\":\"set_rally\"}",
	"14|sel=[10]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=true|{\"builder_id\":10,\"building_id\":13,\"player\":1,\"sequence\":7,\"tick\":1,\"type\":\"resume_build\"}",
	"15|sel=[]|bld=14|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=true|{\"player\":1,\"sequence\":8,\"target_id\":14,\"tick\":1,\"type\":\"unload\"}",
	"16|sel=[11]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=true|{\"entity_ids\":[11],\"player\":1,\"sequence\":9,\"target_id\":14,\"tick\":1,\"type\":\"enter\"}",
	"17|sel=[10]|bld=-1|insp=-1|place=frc_supply_center|sub=true|am=false|esc=true|menu=false|perf=true|",
	"18|sel=[10]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=true|",
	"19|sel=[]|bld=-1|insp=9|place=|sub=false|am=false|esc=true|menu=false|perf=true||refusal=",
	"20|sel=[10]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=true|{\"entity_ids\":[10],\"player\":1,\"sequence\":10,\"source_id\":16,\"tick\":1,\"type\":\"gather\"}",
	"21|sel=[10]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=true||tick=2",
]

const IC2_ROWS: PackedStringArray = [
	"1|sel=[3]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=false|",
	"2|sel=[3]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=false|{\"entity_ids\":[3],\"player\":1,\"sequence\":1,\"target\":[12.5,18.5],\"tick\":16,\"type\":\"move\"}",
	"4|sel=[3]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=false|",
	"6|sel=[3]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=false|",
	"7|sel=[]|bld=-1|insp=-1|place=|sub=false|am=false|esc=false|menu=false|perf=false|",
	"8|sel=[]|bld=-1|insp=-1|place=|sub=false|am=false|esc=false|menu=false|perf=false|",
	"9|sel=[3]|bld=-1|insp=-1|place=usa_power_plant|sub=true|am=false|esc=true|menu=false|perf=false||refusal=",
	"10|sel=[3]|bld=-1|insp=-1|place=usa_power_plant|sub=true|am=false|esc=true|menu=false|perf=true|",
	"11|sel=[3]|bld=-1|insp=-1|place=|sub=true|am=false|esc=true|menu=false|perf=true|{\"builder_id\":3,\"building_kind\":\"usa_power_plant\",\"origin\":[10,10],\"player\":1,\"sequence\":2,\"tick\":37,\"type\":\"build\"}",
	"17|sel=[3]|bld=-1|insp=-1|place=usa_power_plant|sub=true|am=false|esc=true|menu=false|perf=true|",
	"18|sel=[3]|bld=-1|insp=-1|place=|sub=false|am=false|esc=true|menu=false|perf=true|",
]
