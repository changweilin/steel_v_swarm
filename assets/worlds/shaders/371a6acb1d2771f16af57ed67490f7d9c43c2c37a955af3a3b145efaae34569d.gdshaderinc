// Generated from the original marine shader; do not edit derived resources.
uniform sampler2D uSeaField : filter_linear, repeat_disable;
uniform vec4 uSeaRect;
uniform float uWaterY;
uniform float uFoamA;
uniform vec3 uFoamC;
uniform vec3 uNativeKeyColor;
uniform vec3 uCelRampTint;
uniform float uCelRampFb;
uniform float uCelRampLo;
uniform float uCelRim;
uniform float uCelRimScale;
uniform float uRenderStyle;
uniform float uCelWash;
uniform float uCelCool;
uniform sampler2D gradientMap : filter_nearest, repeat_disable;
uniform sampler2D uCelWField : filter_linear, repeat_disable;
uniform vec4 uCelWRect;
uniform float uCelWSpread;
float saturate(float value) { return clamp(value, 0.0, 1.0); }
#define RECIPROCAL_PI (1.0 / PI)

uniform float uCelCutLo;
uniform float uCelCutHi;
uniform float uCelShadowV;
uniform float uCelCutWidth;
float celLum( vec3 c ) { return dot( c, vec3( 0.2126, 0.7152, 0.0722 ) ); }


float celRampDepth( float g ) {
    return clamp( ( g - uCelRampLo ) / max( 1e-3, 1.0 - uCelRampLo ), 0.0, 1.0 );
  }

vec3 getGradientIrradiance( vec3 normal, vec3 lightDirection ) {
	float dotNL = dot( normal, lightDirection );
	vec2 coord = vec2( dotNL * 0.5 + 0.5, 0.0 );
	#ifdef USE_GRADIENTMAP
		
    {
      
      return vec3( saturate( dotNL ) );
    }
	#else
		vec2 fw = fwidth( coord ) * 0.5;
		return mix( vec3( 0.7 ), vec3( 1.0 ), smoothstep( 0.7 - fw.x, 0.7 + fw.x, coord.x ) );
	#endif
}

vec3 inverseTransformDirection( in vec3 dir, in mat4 matrix ) {
	return normalize( ( vec4( dir, 0.0 ) * matrix ).xyz );
}


        uniform float uWindT;
        uniform vec2 uWindDir;
        uniform vec2 uWindK;
        uniform vec2 uGustK;
        uniform float uSoftSpan;
        uniform float uSoftBase;
        uniform float uSoftSy;
        uniform float uSoftAmp;
        uniform float uSoftFreq;
        uniform float uSoftLag;
        uniform float uWeatherWindAmp;
        uniform float uWeatherWindFreq;
        uniform float uWeatherWaveAmp;
        uniform float uWeatherWaveSpeed;
        uniform float uWeatherWindT;
        uniform float uWeatherWaveT;
        uniform float uWeatherGustT;
        uniform vec4 uWeatherWindShape;
        uniform vec4 uWeatherWaterShape;
        
        
        
        float celGust( vec2 celGxz ) {
          return 1.0 + 0.550 * uWeatherWindShape.z * sin( uWeatherGustT * 0.210 + dot( celGxz, uGustK ) );
        }

        #ifdef CEL_SWAMP_RIPPLE
        uniform vec4 uRipple[ 5 ];   
        float celSwampRipple( vec2 celRxz ) {
          float celRsum = 0.0;
          for ( int i = 0; i < 5; i++ ) {
            vec2 celRc = uRipple[ i ].xy;
            float celRt0 = uRipple[ i ].z;
            float celRa = uRipple[ i ].w;
            float celRage = uWindT - celRt0;
            if ( celRage < 0.0 || celRage > 4.0 ) continue;
            float celRr = length( celRxz - celRc );
            float celRfront = celRage * 2.5;
            float celRrd = abs( celRr - celRfront );
            
            float celRring = exp( -celRrd * celRrd * 6.0 )
                           * exp( -celRr * celRr / 64.0 )
                           * ( 1.0 - celRage / 4.0 );
            celRsum += celRa * celRring * sin( celRr * 5.0 - celRage * 8.0 );
          }
          return celRsum;
        }
        #endif

        uniform vec4 uSeaSources[ 12 ];
        uniform vec4 uSeaSourceShape[ 12 ];

        
        vec3 celSeaPhases( vec2 p, vec2 dir, vec4 field, float scale ) {
          float k = 0.09817 * scale;
          vec2 slope = ( field.ba * 255.0 - 128.0 ) / 127.0;
          float slopeLen = length( slope );
          vec2 normal = -slope / max( slopeLen, 0.0001 );
          float incidence = dot( dir, normal );
          float depth = field.g * 32.00;
          float travel = min( depth / max( slopeLen, 0.02 ), 64.00 );
          float bend = smoothstep( 0.015, 0.14, slopeLen ) * ( 1.0 - field.g );
          float delay = k * incidence * travel * bend * 0.4333;
          float phase = dot( p, dir ) * k;
          float reflected = phase + 2.0 * k * incidence * travel + delay;
          float reflectWeight = smoothstep( 0.02, 0.18, slopeLen )
            * ( 1.0 - smoothstep( 0.03, 0.45, field.g ) )
            * smoothstep( 0.05, 0.65, incidence ) * 0.240;
          return vec3( phase - delay, reflected, reflectWeight );
        }

        float celVesselWaves( vec2 p ) {
          float height = 0.0;
          for ( int i = 0; i < 12; i++ ) {
            vec4 shape = uSeaSourceShape[ i ];
            if ( shape.w <= 0.0 ) continue;
            vec4 source = uSeaSources[ i ];
            vec2 rel = p - source.xy;
            float range = min( 64.00 * 2.0, max( 64.00 * 0.5, shape.x * 2.0 ) );
            if ( dot( rel, rel ) > range * range ) continue;
            float along = dot( rel, source.zw );
            float across = dot( rel, vec2( -source.w, source.z ) );
            float stern = max( 0.0, -along - shape.x * 0.5 );
            float spread = max( shape.y, 8.00 );
            float moving = smoothstep( 0.2, 2.0, shape.z );
            
            float wakeDist = abs( across ) - stern * 0.36;
            float wake = exp( -wakeDist * wakeDist / ( spread * spread ) )
              * smoothstep( 0.0, spread, stern ) * exp( -stern / range );
            float radial = length( vec2( across, max( 0.0, abs( along ) - shape.x * 0.5 ) ) );
            float phase = mix( radial, wakeDist, moving ) * 0.19635
              - uWeatherWaveT * uSoftFreq * mix( 0.8, 1.8, moving );
            float envelope = mix( exp( -radial / spread ) * 0.18, wake * 0.35, moving );
            height += sin( phase ) * envelope * ( 1.0 - smoothstep( range * 0.65, range, length( rel ) ) );
          }
          return height * uSoftAmp * uWeatherWaveAmp;
        }

        
        
        float celSwampBedError( vec2 p ) {
          vec2 c1 = floor( p * 0.85 );
          vec2 c2 = floor( p * 1.65 + vec2( 0.43, 0.67 ) );
          vec2 c3 = floor( p * 2.80 - vec2( 0.28, 0.81 ) );
          float h1 = fract( sin( dot( c1, vec2( 127.1, 311.7 ) ) ) * 43758.5453 ) * 2.0 - 1.0;
          float h2 = fract( sin( dot( c2, vec2( 269.5, 183.3 ) ) ) * 43758.5453 ) * 2.0 - 1.0;
          float h3 = fract( sin( dot( c3, vec2( 419.2, 371.9 ) ) ) * 43758.5453 ) * 2.0 - 1.0;
          return h1 * 0.48 + h2 * 0.36 + h3 * 0.16;
        }

        
        float celSeaBedError( vec2 p ) {
          vec2 c1 = floor( p * 0.22 );
          vec2 c2 = floor( p * 0.45 + vec2( 0.55, 0.35 ) );
          float h1 = fract( sin( dot( c1, vec2( 127.1, 311.7 ) ) ) * 43758.5453 ) * 2.0 - 1.0;
          float h2 = fract( sin( dot( c2, vec2( 269.5, 183.3 ) ) ) * 43758.5453 ) * 2.0 - 1.0;
          return h1 * 0.65 + h2 * 0.35;
        }

        
        
        
        
        float celSeaH( vec2 celSxz ) {
          if ( uWeatherWaveAmp <= 0.001 ) return 0.0;
          
          vec2 celWarp = vec2(
            sin( celSxz.y * 0.038 + celSxz.x * 0.015 + uWeatherWaveT * 0.16 ) * 5.2
              + sin( celSxz.y * 0.082 - celSxz.x * 0.041 + 2.37 ) * 2.6,
            cos( celSxz.x * 0.034 - celSxz.y * 0.019 + uWeatherWaveT * 0.13 ) * 5.2
              + cos( celSxz.x * 0.076 + celSxz.y * 0.043 + 1.19 ) * 2.6
          );
          vec2 celWxz = celSxz + celWarp;

          
          float celSn = sin( dot( celWxz, vec2( 0.0523, 0.0321 ) ) ) * 0.62
                      + sin( dot( celWxz, vec2( -0.0233, 0.0711 ) ) + 2.13 ) * 0.38;
          float celSn2 = sin( dot( celWxz, vec2( 0.0951, -0.0583 ) ) + 4.31 ) * 0.58
                       + sin( dot( celWxz, vec2( -0.0773, -0.1071 ) ) + 1.25 ) * 0.42;
          float celAmpMod = 1.0 + celSn * 0.350;
          float celPhJit = celSn2 * 1.2;

          
          vec2 celDuv = clamp( ( celSxz - uSeaRect.xy ) * uSeaRect.zw, vec2( 0.0 ), vec2( 1.0 ) );
          vec4 celWaterField = texture( uSeaField, celDuv );
          float celRawD = celWaterField.r;
          float celDepF = smoothstep( 0.0, 0.5, celRawD );

          
          float celAmpD = mix( 1.300, 1.0, celDepF );

          
          float celObD = smoothstep( 0.0, 0.15, celRawD );

          
          float celSeaBed = celSeaBedError( celSxz );
          float seaBedWarp = celSeaBed * 0.25;
          float celSpread = mix( 0.45, 1.05, uWeatherWaterShape.z );
          vec2 celCrossDir = vec2( uWindDir.x * cos( celSpread ) - uWindDir.y * sin( celSpread ),
            uWindDir.x * sin( celSpread ) + uWindDir.y * cos( celSpread ) );
          vec2 celSwellDir = vec2( 0.62932,
            0.77715 );
          vec3 celMainP = celSeaPhases( celWxz, uWindDir, celWaterField, 1.0 );
          vec3 celCrossP = celSeaPhases( celWxz, celCrossDir, celWaterField, 1.25 );
          vec3 celSwellP = celSeaPhases( celWxz, celSwellDir, celWaterField, 0.72 );
          float celMsp = celMainP.x + seaBedWarp + celPhJit;
          float celPrimary = sin( celMsp - uWeatherWaveT * uSoftFreq );
          
          float celCrest = celPrimary + uWeatherWaterShape.x * ( celPrimary * celPrimary - 0.5 );
          float celCross = sin( celCrossP.x - uWeatherWaveT * uSoftFreq * 1.12 + celPhJit );
          float celSwell = sin( celSwellP.x - uWeatherWaveT * uSoftFreq * 0.85 + 1.7 );
          float celReflected = sin( celMainP.y - uWeatherWaveT * uSoftFreq + celPhJit ) * celMainP.z
            + sin( celCrossP.y - uWeatherWaveT * uSoftFreq * 1.12 + celPhJit ) * celCrossP.z * 0.5
            + sin( celSwellP.y - uWeatherWaveT * uSoftFreq * 0.85 + 1.7 ) * celSwellP.z * 0.4;
          float celHSea = ( uSoftAmp * uWeatherWaveAmp ) * (
            celAmpD * celAmpMod * celObD * celGust( celSxz )
            * ( celCrest * ( 0.72 - uWeatherWaterShape.y )
              + celSwell * 0.28 + celCross * uWeatherWaterShape.y + celReflected )
            + celSeaBed * 0.15 * mix( 0.85, 0.25, celDepF )
          );

          
          float celBedErr = celSwampBedError( celSxz );
          float celSwampWarp = sin( dot( celSxz, vec2( 0.35, 0.24 ) ) + uWeatherWaveT * 0.55 ) * 1.2
                             + cos( dot( celSxz, vec2( -0.28, 0.36 ) ) + uWeatherWaveT * 0.42 ) * 0.8
                             + vec2( cos( celBedErr * 3.14159 ), sin( celBedErr * 3.14159 ) ).x * 0.65;
          float celHSwamp = ( uSoftAmp * uWeatherWaveAmp ) * (
            sin( uWeatherWaveT * 0.95 + dot( celSxz, vec2( 0.45, 0.32 ) ) + celSwampWarp + celBedErr * 1.15 ) * 0.45
            + cos( uWeatherWaveT * 0.72 + dot( celSxz, vec2( -0.36, 0.48 ) ) + celSwampWarp * 0.4 ) * 0.30
            + sin( uWeatherWaveT * 1.25 + dot( celSxz, vec2( 0.65, -0.55 ) ) ) * 0.15
            + celBedErr * 0.55
          );

          #ifdef CEL_SWAMP_RIPPLE
          
          float celH = mix( celHSwamp, celHSea, celDepF * 0.65 );
          #else
          
          float celSwampBlend = 1.0 - celDepF; 
          float celH = mix( celHSea, celHSwamp, celSwampBlend * 0.65 );
          #endif

          
          float celFragW = ( 1.0 - celDepF ) * 0.65;
          #ifdef CEL_SWAMP_RIPPLE
          celFragW = max( celFragW, 0.95 );
          #endif
          if ( celFragW > 0.01 ) {
            float celChop = sin( dot( celSxz, vec2( 0.95, 0.68 ) ) + uWeatherWaveT * 1.5 + celSwampWarp * 0.6 )
                          * cos( dot( celSxz, vec2( -0.72, 0.85 ) ) + uWeatherWaveT * 1.2 )
                          + sin( dot( celSxz, vec2( 1.45, -1.12 ) ) - uWeatherWaveT * 1.8 ) * 0.4;
            celH += uSoftAmp * uWeatherWaveAmp * 0.45 * celFragW * celChop * mix( 0.15, 1.0, uWeatherWaterShape.z );
          }

          celH += celVesselWaves( celSxz );

          #ifdef CEL_SWAMP_RIPPLE
          celH += celSwampRipple( celSxz ) * uWeatherWaveAmp;
          #endif
          return celH;
        }
float celHash( vec2 p ) { return fract( sin( dot( p, vec2( 127.1, 311.7 ) ) ) * 43758.5453 ); }

float celNoise( vec2 p ) {
          vec2 i = floor( p ), f = fract( p );
          f = f * f * ( 3.0 - 2.0 * f );
          return mix( mix( celHash( i ), celHash( i + vec2( 1.0, 0.0 ) ), f.x ),
                      mix( celHash( i + vec2( 0.0, 1.0 ) ), celHash( i + vec2( 1.0, 1.0 ) ), f.x ), f.y );
        }

float celFoam( vec2 celFxz ) {
          if ( uWeatherWaveAmp <= 0.001 ) return 0.0;
          vec2 celFuv = clamp( ( celFxz - uSeaRect.xy ) * uSeaRect.zw, 0.0, 1.0 );
          float celFd = texture( uSeaField, celFuv ).r * 2.40;
          float celFade = clamp( 1.0 - celFd / 2.40, 0.0, 1.0 );
          if ( celFade <= 0.0 ) return 0.0;
          if ( celFd <= 0.001 ) return 0.0;
          float celFb = fract( ( celFd - celSeaH( celFxz ) ) / 0.550 );
          float celBand = max( 0.0, 4.0 * celFb * ( 1.0 - celFb ) );
          float celFp = pow( celBand, 5.0 ) * celFade
                      * mix( 0.45, 1.0, celNoise( celFxz / 3.40 ) );
          #ifdef CEL_SWAMP_RIPPLE
          
          float celSwampPulse = sin( uWindT * 1.5 + dot( celFxz, vec2( 0.45, 0.35 ) ) ) * 0.54 + 0.46; 
          celFp *= clamp( celSwampPulse, 0.0, 1.0 );
          #endif
          return step( 0.42, celFp );   
        }

float celWeatherF(vec3 vCelWP) {
          #ifdef CEL_WP
            vec2 wuv = clamp( ( vCelWP.xz - uCelWRect.xy ) * uCelWRect.zw, 0.0, 1.0 );
            return 1.0 + ( texture( uCelWField, wuv ).r - 0.5 ) * 2.0 * uCelWSpread;
          #else
            return 1.0;
          #endif
        }

void celMarineWash(inout vec4 diffuseColor, vec3 vCelWP) {
  #ifdef CEL_WASH
  
            
            
            float celN = celNoise( vCelWP.xz * 0.011 );
            vec3 celTint = mix( vec3( 0.93, 0.965, 1.06 ), vec3( 1.07, 1.025, 0.94 ), celN );
            diffuseColor.rgb *= mix( vec3( 1.0 ), celTint, uCelWash * celWeatherF(vCelWP) );
          
  #endif
}
struct NativeMarineLight {
  vec3 directDiffuse;
  vec3 indirectDiffuse;
};
vec3 celMarineLightFinish(vec3 outgoingLight, vec4 diffuseColor, vec3 diffuse, vec3 directDiffuse, vec3 indirectDiffuse,
  vec3 totalEmissiveRadiance, vec3 vCelWP, vec3 vViewPosition, vec3 normal, mat4 viewMatrix, vec3 uCelLightDir, vec3 nativeKeyColor) {
  NativeMarineLight reflectedLight;
  reflectedLight.directDiffuse = directDiffuse;
  reflectedLight.indirectDiffuse = indirectDiffuse;
  
          {
            
            vec3 celKey = nativeKeyColor;
            vec3 celOn = diffuseColor.rgb * celKey * RECIPROCAL_PI;
            float celOnL = celLum( celOn );
            float celLit = celOnL > 1e-6 ? saturate( celLum( reflectedLight.directDiffuse ) / celOnL ) : 0.0;
            float celMid = ( uCelCutLo + uCelCutHi ) * 0.5;
            celLit = clamp( celMid + ( celLit - celMid ) / uCelCutWidth, 0.0, 1.0 );
            float celCut = smoothstep( uCelCutLo, uCelCutHi, celLit );
            vec3 celOff = celOn * uCelRampTint;
            celOff *= uCelShadowV * celOnL / max( 1e-6, celLum( celOff ) );
            outgoingLight = mix( celOff, celOn, celCut ) + reflectedLight.indirectDiffuse + totalEmissiveRadiance;
          }
          vec3 celV = normalize( vViewPosition );
          
          float celRim = 1.0 - saturate( dot( normal, celV ) );
          outgoingLight += diffuse.rgb * uCelRim * uCelRimScale * smoothstep( 0.62, 0.78, celRim );
          #ifdef CEL_METAL
            
            vec3 celH = normalize( uCelLightDir + celV );
            float celS = pow( saturate( dot( normal, celH ) ), 42.0 );
            outgoingLight += vec3( 0.9 ) * step( 0.5, celS );
          #endif
          #ifdef CEL_COOL
            
            
            float celShade = smoothstep( 0.05, 0.45, dot( normal, uCelLightDir ) );
            outgoingLight = mix( outgoingLight * mix( vec3( 1.0 ), vec3( 0.86, 0.93, 1.1 ), uCelCool ), outgoingLight, celShade );
          #endif
          
          
          
          
          
          
          
          
          if ( uCelRampFb > 0.5 ) {
            #ifdef USE_GRADIENTMAP
              float celFbG = texture( gradientMap, vec2( dot( normal, uCelLightDir ) * 0.5 + 0.5, 0.0 ) ).r;
              float celFbW = celRampDepth( celFbG );
            #else
              float celFbG = saturate( dot( normal, uCelLightDir ) * 0.5 + 0.5 );
              float celFbW = celFbG;   
            #endif
            outgoingLight *= mix( uCelRampTint, vec3( 1.0 ), celFbW );
          }
          
          
          if ( uRenderStyle > 0.5 ) {
            vec3 styWN = normalize( inverseTransformDirection( normal, viewMatrix ) );
            vec3 styH = normalize( uCelLightDir + celV );
            float styNL = dot( normal, uCelLightDir );
            float styNH = saturate( dot( normal, styH ) );
            vec3 styP = vViewPosition;
            #ifdef CEL_INKB
              styP = vCelInkP;
            #endif
            #ifdef CEL_WP
              styP = vCelWP * 0.35;
            #endif
            vec3 styLumaW = vec3( 0.2126, 0.7152, 0.0722 );
            float styOutL = dot( outgoingLight, styLumaW );
            vec3 styAlb = max( diffuseColor.rgb, vec3( 0.02 ) );
            float styAlbL = max( 1e-4, dot( styAlb, styLumaW ) );
            
            float styEnergy = styOutL / styAlbL;

            if ( uRenderStyle > 6.5 ) {
              
              float styBand = step( -0.12, styNL ) * 0.55 + step( 0.55, styNL ) * 0.45;
              vec3 styTint = mix( vec3( 0.93, 0.89, 1.08 ), vec3( 1.04, 1.02, 0.94 ), styBand );
              outgoingLight *= styTint;
            } else if ( uRenderStyle > 5.5 ) {
              
              float styPrint = celNoise( styP.xz * 1.8 + styP.xy * 0.7 ) - 0.5;
              vec3 styMuted = mix( vec3( styOutL ), outgoingLight, 0.86 );
              vec3 styPaper = mix( vec3( 0.93, 1.01, 1.0 ), vec3( 1.04, 1.02, 0.93 ), step( 0.12, styNL ) );
              outgoingLight = styMuted * styPaper * ( 1.0 + styPrint * 0.035 );
            } else if ( uRenderStyle < 1.5 ) {
              
              float stySmoothL = mix( 0.34, 1.16, smoothstep( -0.32, 0.88, styNL ) );
              vec3 styHemi = mix( vec3( 0.86, 0.82, 0.78 ), vec3( 1.06, 1.09, 1.15 ), styWN.y * 0.5 + 0.5 );
              vec3 styPbr = styAlb * styEnergy * stySmoothL * styHemi;
              #ifdef CEL_METAL
                float stySpec = pow( styNH, 96.0 ) * 0.75 + pow( styNH, 20.0 ) * 0.25;
                styPbr = styPbr * 0.88 + mix( styAlb, vec3( 1.0 ), 0.65 ) * stySpec * max( 0.25, styEnergy );
              #else
                float stySpec = pow( styNH, 32.0 ) * 0.16 * saturate( styNL + 0.2 );
                styPbr += vec3( stySpec ) * max( 0.25, styEnergy );
              #endif
              float styFres = pow( celRim, 3.6 ) * 0.18;
              outgoingLight = mix( outgoingLight, styPbr + styAlb * styFres * styEnergy, 0.78 ) + totalEmissiveRadiance * 0.22;
            } else if ( uRenderStyle < 2.5 ) {
              
              float styB1 = celNoise( styP.xz * 1.85 + styP.xy * 0.95 );
              float styB2 = celNoise( styP.yz * 3.40 - styP.xz * 1.30 + 7.3 );
              float styBrush = ( styB1 * 0.62 + styB2 * 0.38 ) - 0.5;
              float styFacetNL = styNL + styBrush * 0.42;
              float styBand = floor( saturate( styFacetNL * 0.5 + 0.5 ) * 4.0 ) / 3.0;
              
              float styTerm = smoothstep( -0.25, 0.05, styFacetNL ) * ( 1.0 - smoothstep( 0.05, 0.38, styFacetNL ) );
              vec3 styCoolSh = outgoingLight * vec3( 0.78, 0.84, 1.12 );
              vec3 styWarmMid = outgoingLight * vec3( 1.24, 0.94, 0.76 );
              vec3 styWarmHi = outgoingLight * vec3( 1.14, 1.08, 0.94 );
              vec3 styImp = mix( styCoolSh, styWarmHi, styBand );
              styImp = mix( styImp, styWarmMid, styTerm * 0.58 );
              float styDab = smoothstep( 0.54, 0.66, styNH + styBrush * 0.16 );
              outgoingLight = styImp + mix( styAlb, vec3( 1.0, 0.97, 0.88 ), 0.7 ) * styDab * 0.28 * max( 0.3, styEnergy );
            } else if ( uRenderStyle < 3.5 ) {
              
              float styInkN = celNoise( styP.xz * 1.4 + styP.yy * 0.8 ) * 0.6 + celNoise( styP.yz * 3.1 + 4.7 ) * 0.4;
              float styGraz = pow( celRim, 1.45 );
              
              float styFeibai = smoothstep( 0.24, 0.76, styGraz + ( styInkN - 0.48 ) * 0.45 );
              float styWashL = dot( outgoingLight, styLumaW );
              
              vec3 styMineral = mix( vec3( styWashL ), outgoingLight, 0.56 );
              styMineral *= mix( vec3( 0.88, 0.95, 0.98 ), vec3( 1.06, 0.98, 0.86 ), saturate( styNL * 0.5 + 0.5 ) );
              
              vec3 styPaper = vec3( 0.96, 0.93, 0.86 ) * max( styWashL, 0.32 );
              float styWhiteBleed = smoothstep( 0.42, 0.88, styNL + ( styInkN - 0.5 ) * 0.28 ) * 0.46;
              vec3 stySumi = mix( styMineral, styPaper, styWhiteBleed );
              vec3 styDarkInk = stySumi * vec3( 0.22, 0.24, 0.28 );
              outgoingLight = mix( stySumi, styDarkInk, styFeibai * 0.65 );
            } else if ( uRenderStyle < 4.5 ) {
              
              float styWn1 = celNoise( styP.xz * 0.75 + styP.xy * 0.45 );
              float styWn2 = celNoise( styP.yz * 1.90 + 9.2 );
              float styTurb = ( styWn1 * 0.65 + styWn2 * 0.35 ) - 0.5;
              
              float styTermRing = exp( -pow( ( styNL + styTurb * 0.32 - 0.04 ) * 4.8, 2.0 ) );
              float styEdgePool = smoothstep( 0.48, 0.86, celRim + styTurb * 0.22 );
              float styPool = max( styTermRing * 0.75, styEdgePool * 0.65 );
              
              vec3 styPigment = pow( max( outgoingLight, vec3( 1e-4 ) ), vec3( 1.28 ) ) * vec3( 0.82, 0.78, 0.92 );
              vec3 styPaperHi = mix( outgoingLight, vec3( 0.99, 0.97, 0.92 ) * max( styOutL * 1.25, 0.38 ),
                                     smoothstep( 0.25, 0.82, styNL - styTurb * 0.25 ) * 0.52 );
              outgoingLight = mix( styPaperHi, styPigment, styPool * 0.58 );
            } else {
              
              vec2 styFlow = vec2( styP.x * 3.8 + styP.z * 1.2, styP.y * 0.95 - styP.z * 0.65 );
              float styBr0 = celNoise( styFlow );
              float styBr1 = celNoise( styFlow + vec2( 0.35, 0.08 ) );
              float styRidge = ( styBr1 - styBr0 ) * 3.2;   
              float styOilNL = styNL + styRidge * 0.28;
              float styWarmth = smoothstep( -0.35, 0.65, styOilNL );
              vec3 styOilSh = outgoingLight * vec3( 0.74, 0.80, 1.08 );   
              vec3 styOilHi = outgoingLight * vec3( 1.18, 1.06, 0.86 );   
              vec3 styOil = mix( styOilSh, styOilHi, styWarmth );
              styOil *= 1.0 + styRidge * 0.22;
              
              float styVarnish = pow( saturate( styNH + styRidge * 0.18 ), 24.0 ) * 0.34;
              outgoingLight = styOil + vec3( 1.0, 0.95, 0.82 ) * styVarnish * max( 0.25, styEnergy );
            }
          }
        
  return outgoingLight;
}
vec3 celMarineNormal(vec3 position, mat4 modelMatrix, float seaFade) {
  vec3 objectNormal;
  
          
          
          vec2 seaN0 = ( modelMatrix * vec4( position, 1.0 ) ).xz;
          #ifdef CEL_SWAMP_RIPPLE
          float seaE = 0.50; 
          #else
          float seaE = 4.000;
          #endif
          vec3 seaNw = vec3(
            celSeaH( seaN0 - vec2( seaE, 0.0 ) ) - celSeaH( seaN0 + vec2( seaE, 0.0 ) ),
            2.0 * seaE,
            celSeaH( seaN0 - vec2( 0.0, seaE ) ) - celSeaH( seaN0 + vec2( 0.0, seaE ) ) );
          seaNw.xz *= seaFade;
          
          objectNormal = normalize( normalize( seaNw ) * mat3( modelMatrix ) + vec3( 1e-6 ) );
        
  return objectNormal;
}
void celMarineReflection(inout vec3 transformed, vec3 aReflO, vec3 cameraPosition, float seaFade) {
  
          
          
          
          
          
          float rE = max( 0.1, cameraPosition.y - uWaterY );
          vec2 rD2 = cameraPosition.xz - aReflO.xy;
          float rD = length( rD2 );
          vec2 rDir = rD2 / max( rD, 1e-4 );
          float rLen = min( rD * aReflO.z / ( rE + aReflO.z ), 18.0 );
          vec2 rNrm = vec2( -rDir.y, rDir.x );
          vec2 rP = aReflO.xy + rDir * ( rLen * transformed.y ) + rNrm * transformed.x;
          transformed = vec3( rP.x, uWaterY + celSeaH( rP ) * seaFade, rP.y );
        
}
void celMarineDisplace(inout vec3 transformed, mat4 modelMatrix, float seaFade) {
  
          
          
          vec2 seaXZ = ( modelMatrix * vec4( transformed, 1.0 ) ).xz;
          
          
          vec3 seaUp = normalize( vec3( 0.0, 1.0, 0.0 ) * mat3( modelMatrix ) + vec3( 1e-6 ) );
          transformed += seaUp * ( celSeaH( seaXZ ) * seaFade );
          
        
}
void celMarineFinish(inout vec4 nativeColor, vec3 vCelWP, float vSeaFade, vec3 vViewPosition, vec3 normal, vec3 uCelLightDir) {
  
          
          
          
          
          
          float celF = celFoam( vCelWP.xz ) * vSeaFade * uFoamA;
          #ifndef CEL_SWAMP_RIPPLE
          if ( uWeatherWaterShape.w > 0.001 && uWeatherWaveAmp > 0.001 ) {
            
            float crest = celSeaH( vCelWP.xz ) / max( 0.001, uSoftAmp * uWeatherWaveAmp );
            float foamPatch = celNoise( vCelWP.xz / 5.0 - uWindDir * uWeatherWaveT * 0.4 );
            float whitecap = smoothstep( 0.62, 0.95, crest ) * step( 0.48, foamPatch );
            celF = max( celF, whitecap * uWeatherWaterShape.w * vSeaFade * uFoamA );
          }
          #endif
          if ( celF > 0.0 ) {
            nativeColor.rgb = mix( nativeColor.rgb, uFoamC, celF );
            nativeColor.a = mix( nativeColor.a, 1.0, celF );
          }

          
          #ifdef CEL_SWAMP_RIPPLE
          
          float celFragBedErr = celSwampBedError( vCelWP.xz );
          vec2 celWarpUV = vCelWP.xz + vec2(
            sin( vCelWP.z * 0.28 + uWeatherWaveT * 0.42 ) * 1.8 + cos( vCelWP.x * 0.45 + 1.7 ) * 1.0 + celFragBedErr * 0.45,
            cos( vCelWP.x * 0.24 - uWeatherWaveT * 0.38 ) * 1.8 + sin( vCelWP.z * 0.41 + 2.3 ) * 1.0 - celFragBedErr * 0.45
          );
          vec2 celSwRipUV = celWarpUV * 0.65;
          float celRipN1 = celNoise( celSwRipUV * 2.0 + vec2( uWeatherWaveT * 0.22, -uWeatherWaveT * 0.18 ) );
          float celRipN2 = celNoise( celSwRipUV * 3.8 - vec2( uWeatherWaveT * 0.28, uWeatherWaveT * 0.22 ) + 5.17 );
          float celRipN3 = celNoise( celSwRipUV * 7.2 + vec2( -uWeatherWaveT * 0.35, uWeatherWaveT * 0.30 ) + 3.41 );
          
          
          float celWave1 = sin( dot( celWarpUV, vec2( 0.52, 0.36 ) ) * 2.2 + uWeatherWaveT * 1.15 + celRipN1 * 3.6 + celFragBedErr * 0.95 ) * 0.5 + 0.5;
          float celWave2 = cos( dot( celWarpUV, vec2( -0.42, 0.62 ) ) * 2.5 - uWeatherWaveT * 0.95 + celRipN2 * 3.2 - celFragBedErr * 0.85 ) * 0.5 + 0.5;
          float celWave3 = sin( dot( celWarpUV, vec2( 0.78, -0.65 ) ) * 3.1 + uWeatherWaveT * 1.35 + celRipN3 * 2.4 ) * 0.5 + 0.5;
          
          
          float celBrokenBand = pow( celWave1 * celWave2 * 1.35, 2.4 ) + pow( celWave2 * celWave3 * 1.35, 2.6 ) * 0.8;
          float celBreakMask = smoothstep( 0.25, 0.65, celRipN2 * 0.55 + celRipN3 * 0.45 );
          float celSwampRippleLine = step( 0.60, celBrokenBand * celBreakMask ) * vSeaFade * min( 1.0, uWeatherWaveAmp * 2.0 ) * mix( 0.2, 1.0, uWeatherWaterShape.z );
          
          if ( celSwampRippleLine > 0.0 ) {
            vec3 swampRippleColor = vec3( 0.72, 0.86, 0.62 ); 
            nativeColor.rgb = mix( nativeColor.rgb, swampRippleColor, celSwampRippleLine * 0.45 );
          }

          
          vec3 bedShading = vec3( 0.04, 0.06, 0.03 ) * celFragBedErr * 0.45 * vSeaFade;
          nativeColor.rgb = clamp( nativeColor.rgb + bedShading, 0.0, 1.0 );
          #else
          
          float celFragSeaBed = celSeaBedError( vCelWP.xz );
          vec2 celDuvPre = clamp( ( vCelWP.xz - uSeaRect.xy ) * uSeaRect.zw, vec2( 0.0 ), vec2( 1.0 ) );
          float celRawDPre = texture( uSeaField, celDuvPre ).r;
          vec3 seaBedShading = vec3( 0.02, 0.035, 0.04 ) * celFragSeaBed * 0.18 * ( 1.0 - celRawDPre * 0.75 ) * vSeaFade;
          nativeColor.rgb = clamp( nativeColor.rgb + seaBedShading, 0.0, 1.0 );
          #endif

          
          #ifdef CEL_SWAMP_RIPPLE
          vec2 celBedShimmerOffset = vec2( celFragBedErr * 0.35, -celFragBedErr * 0.35 );
          #else
          vec2 celBedShimmerOffset = vec2( celFragSeaBed * 0.15, -celFragSeaBed * 0.15 );
          #endif
          vec2 celShimmerUV = vCelWP.xz * 2.4 + vec2( sin( uWeatherWaveT * 1.8 + vCelWP.z * 0.4 ), cos( uWeatherWaveT * 1.5 + vCelWP.x * 0.4 ) ) * 0.35 + celBedShimmerOffset;
          float celShN1 = celNoise( celShimmerUV );
          float celShN2 = celNoise( celShimmerUV * 2.5 + vec2( 5.31, 11.17 ) + uWeatherWaveT * 0.9 );
          float celSparkle = pow( celShN1 * celShN2, 3.2 );
          
          float celChopLine = smoothstep( 0.82, 0.96,
            sin( dot( vCelWP.xz, uWindDir ) * 0.9 - uWeatherWaveT * 1.6 + celShN1 * 2.0 ) * 0.5 + 0.5 );
          celChopLine *= celShN2 * uWeatherWaterShape.z * vSeaFade * min( 1.0, uWeatherWaveAmp * 2.0 );
          nativeColor.rgb = mix( nativeColor.rgb, vec3( 0.86, 0.94, 0.98 ), celChopLine * 0.28 );
          vec3 celWaterV = normalize( vViewPosition );
          vec3 celWaterH = normalize( uCelLightDir + celWaterV );
          float celWaterSpec = pow( max( 0.0, dot( normal, celWaterH ) ), 32.0 );

          
          vec2 celDuvFrag = clamp( ( vCelWP.xz - uSeaRect.xy ) * uSeaRect.zw, vec2( 0.0 ), vec2( 1.0 ) );
          float celRawDFrag = texture( uSeaField, celDuvFrag ).r;
          float celShallowF = smoothstep( 0.65, 0.05, celRawDFrag );
          #ifdef CEL_SWAMP_RIPPLE
          celShallowF = max( celShallowF, 0.85 );
          #endif

          if ( celShallowF > 0.05 ) {
            float celGlint = step( 0.68, ( celWaterSpec * 0.65 + 0.35 ) * celSparkle * 4.5 ) * celShallowF * vSeaFade * min( 1.0, uWeatherWaveAmp * 2.0 );
            if ( celGlint > 0.0 ) {
              #ifdef CEL_SWAMP_RIPPLE
              vec3 glintColor = mix( vec3( 0.82, 0.94, 0.72 ), vec3( 0.94, 0.98, 1.0 ), celRawDFrag ); 
              #else
              vec3 glintColor = mix( vec3( 0.94, 0.98, 1.0 ), vec3( 0.82, 0.94, 0.72 ), celShallowF * 0.5 );  
              #endif
              nativeColor.rgb = mix( nativeColor.rgb, glintColor, celGlint * 0.75 );
            }
          }
        
}
