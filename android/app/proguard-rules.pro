# ML Kit: só o modelo latino está incluído (Fase 7, D1). O plugin refere
# os outros alfabetos; sem estas regras o R8 falha na compilação de release.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
