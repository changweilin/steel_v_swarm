// Offline adapters expose existing uniforms without changing source construction or RNG.
export function instrumentMarineCapture(source) {
  for (const seam of ['const _seaField =', 'const _seaRect =', 'const _seaSources =', 'const _seaSourceShape =']) {
    if (!source.includes(seam)) throw new Error('Missing original marine uniform seam: ' + seam);
  }
  return source + `
export function nativeMarineUniforms() {
  return {field:_seaField.value,rect:_seaRect.value.toArray(),
    sources:_seaSources.value.map(v=>v.toArray()),shapes:_seaSourceShape.value.map(v=>v.toArray()),
    appearance:{school:_school,weatherSpread:WEATHER_SPREAD,renderStyles:{...RENDER_STYLES},
      shadowFloor:rampFloor(3),shadowValue:CEL_CUT.SHADOW_V,hueMinimum:CEL_CUT.HUE_MIN_A,
      shadowHueNormalized:[...SHADOW_HUE_N],tintMaximum:TINT_MAX_A},
    program:{wind:CEL_WIND_GLSL,ripple:CEL_SWAMP_RIPPLE_GLSL,sea:CEL_SEA_GLSL,
      common:THREE.ShaderChunk.common,school:_school}};
}
`;
}

export function captureMarineBundle(toon, textureDescription) {
  const state = toon.nativeMarineUniforms();
  if (!state.field?.isDataTexture || state.rect.length !== 4 || !state.rect.every(Number.isFinite)
    || state.sources.length !== toon.WIND.SEA_SOURCE_N || state.shapes.length !== toon.WIND.SEA_SOURCE_N)
    throw new Error('Invalid original shared marine uniforms');
  for (const packet of [...state.sources,...state.shapes]) {
    if (packet.length !== 4 || !packet.every(Number.isFinite)) throw new Error('Invalid original vessel wave packet');
  }
  return {marineCaptured:true,marine:{wind:{...toon.WIND},foam:{...toon.FOAM},reflection:{...toon.REFL},
    field:textureDescription(state.field),rect:state.rect,sources:state.sources,shapes:state.shapes,appearance:state.appearance}};
}

export function captureMarineMaterial(material, programCapture = null, textureCapture = null) {
  const options = material.userData?.celOpts;
  if (!options || !Object.hasOwn(material.defines || {},'CEL_WAVE')) return null;
  // This invokes only the original text/uniform callback, never a graphics compiler.
  const shader = {uniforms:{},
    vertexShader:'void main() {\n#include <beginnormal_vertex>\n#include <project_vertex>\n}',
    // The cel patch injects its wash block at normal_fragment_begin, after color_fragment as in meshtoon.
    fragmentShader:'#include <gradientmap_pars_fragment>\nvoid main() {\n#include <color_fragment>\n#include <normal_fragment_begin>\n#include <opaque_fragment>\n}'};
  material.onBeforeCompile(shader);
  const uniforms = {};
  const vectors = {};
  for (const name of ['uSoftSpan','uSoftBase','uSoftSy','uSoftAmp','uSoftFreq','uSoftLag','uWaterY',
    'uCelRim','uCelWash','uCelCool','uFoamA','uCelRimScale','uRenderStyle','uCelRampFb','uCelRampLo','uCelWSpread',
    'uWindT','uWeatherWindAmp','uWeatherWindFreq','uWeatherWaveAmp','uWeatherWaveSpeed','uWeatherWindT','uWeatherWaveT','uWeatherGustT']) {
    const value = shader.uniforms[name]?.value;
    if (!Number.isFinite(value)) throw new Error('Invalid original marine material uniform: '+name);
    uniforms[name] = value;
  }
  for (const name of ['uCelCutLo','uCelCutHi','uCelShadowV','uCelCutWidth']) {
    if(!shader.uniforms[name])continue;
    const value=shader.uniforms[name].value;
    if(!Number.isFinite(value))throw new Error('Invalid original cel lighting uniform: '+name);
    uniforms[name]=value;
  }
  for (const name of ['uFoamC','uWindDir','uWindK','uGustK','uWeatherWindShape','uWeatherWaterShape','uCelRampTint','uCelWRect']) {
    const value=shader.uniforms[name]?.value?.toArray?.();
    if(!Array.isArray(value)||![2,3,4].includes(value.length)||!value.every(Number.isFinite))
      throw new Error('Invalid original marine vector uniform: '+name);
    vectors[name]=value;
  }
  const gradient=material.gradientMap?.image;
  if(!(gradient?.data instanceof Uint8Array)||gradient.height!==1||gradient.width!==gradient.data.length)
    throw new Error('Missing original one-channel cel gradient');
  return {kind:options.soft.k,ripple:Object.hasOwn(material.defines,'CEL_SWAMP_RIPPLE'),
    reflection:Object.hasOwn(material.defines,'CEL_REFL'),bands:options.bands,uniforms,vectors,
    defines:Object.keys(material.defines),gradient:Array.from(gradient.data),
    ...(textureCapture?{weatherField:textureCapture(shader.uniforms.uCelWField.value)}:{}),
    ...(programCapture?{program:programCapture(shader)}:{})};
}
