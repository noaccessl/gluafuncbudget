# gluafuncbudget
A utility that serves to conveniently measure performance of functions.</br>
<sub>Brief documentation can be found within the file.</sub></br>
<sub>The name is coined off an analogy with [Source Engines's Showbudget](https://developer.valvesoftware.com/wiki/Showbudget)</sub>

## Demo
```lua
gluafuncbudget.Configure( {

	frames = 60--[["fps"]] * 10000--[["cycles/samples"]];
	iterations_per_frame = 1e3;

	digit = 5;

	measure_unit = 'us';
	comparison_basis = 'average';

	shown_categories = 'total median min max average avgfps minfps maxfps stddevfps';

} )

gluafuncbudget.Queue( {

	name = 'x ^ 2';
	standard = true;

	__x = ( 1 + math.sqrt( 5 ) ) / 2;
	setup = function( this ) return this.__x end;

	main = function( x ) return x ^ 2 end;
	--[[boolean]] jit_off; -- (for reference)

	--[[function]] after -- (for reference)

} )

gluafuncbudget.Queue( {

	name = 'x * x';

	__x = ( 1 + math.sqrt( 5 ) ) / 2;
	setup = function( this ) return this.__x end;

	main = function( x ) return x * x end

} )
```
![gluafuncbudget.png](gluafuncbudget.png)
