shader_type canvas_item;

// Troca o verde do cabelo (99e550) da folha de cabeças por outra cor.
// Só os pixels exatamente dessa cor mudam; pele e contorno continuam iguais.
uniform vec4 cor_cabelo : source_color = vec4(0.6, 0.898, 0.314, 1.0);

const vec3 VERDE_ORIGINAL = vec3(0.6, 0.898, 0.314);

void fragment() {
	if (distance(COLOR.rgb, VERDE_ORIGINAL) < 0.02) {
		COLOR.rgb = cor_cabelo.rgb;
	}
}
