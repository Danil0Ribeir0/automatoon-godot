class_name TrackPath
extends RefCounted

var curve := Curve3D.new()
## Distância (ao longo da curva) do meio de cada PathStep, na mesma ordem de result.steps.
var step_distances := PackedFloat32Array()
## Meio do Spawn: os vagões aparecem a partir daqui.
var appear_at := 0.0
## Meio do último passo: os vagões somem depois daqui.
var vanish_at := 0.0
