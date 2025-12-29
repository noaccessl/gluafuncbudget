--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

	# gluafuncbudget
	A utility that serves to conveniently measure performance of functions.

–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]



--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	Prepare
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
--
-- Functions & Libraries
--
local Color = Color
local MsgC = MsgC
local Format = Format
local table = table
local math = math
local string = string
local Msg = Msg
local pcall = pcall
local jit = jit
local timer = timer
local collectgarbage = collectgarbage


--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	Common Colors
	Constants
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
local WHITE = Color( 255, 255, 255 )

local RED = Color( 255, 85, 85 )
local GRAY = Color( 180, 180, 180 )
local YELLOW = Color( 255, 255, 170 )
local GREEN = Color( 170, 255, 170 )
local DARKAQUA = Color( 0, 170, 170 )

local COL_JIT = Color( 255, 179, 128 )
-- Straight from their website. Fiery color, isn't?

local COL_SV = Color( 156, 241, 255, 200 )
local COL_CL = Color( 255, 241, 122, 200 )
local COL_MN = Color( 100, 220, 100, 200 )

local COL_REALM = CLIENT_DLL and COL_CL or ( GAME_DLL and COL_SV or COL_MN )

local REALMSTR = CLIENT_DLL and 'Client' or ( GAME_DLL and 'Server' or 'Menu' )

local BRANCHSHORT = ( {

	['unknown'] = 'Main';
	['dev'] = 'Dev';
	['prerelease'] = 'Pre';
	['x86-64'] = 'x86-64';
	['network_test'] = 'NWT'

} )[BRANCH]


--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	calculate_mean
	calculate_median
	find_minimal
	find_maximal
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
local function calculate_mean( numset )

	local sum, n = 0, #numset
	for i = 1, n do sum = sum + numset[i] end

	return sum / n

end

local function calculate_median( numset )

	local len = #numset

	local copy = {}
	for i = 1, len do copy[i] = numset[i] end
	table.sort( copy )

	if ( len % 2 == 0 ) then
		return ( copy[len * 0.5] + copy[len * 0.5 + 1] ) * 0.5
	end

	return copy[math.ceil( len * 0.5 )]

end

local function find_minimal( numset )

	local min_true = math.huge

	for i = 1, #numset do

		local min_potential = numset[i]
		min_true = min_potential < min_true and min_potential or min_true

	end

	return min_true

end

local function find_maximal( numset )

	local max_true = -0

	for i = 1, #numset do

		local max_potential = numset[i]
		max_true = max_potential > max_true and max_potential or max_true

	end

	return max_true

end


--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	ms_to_sec
	ms_to_us
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
local function ms_to_sec( ms ) return ms / 1000 end
local function ms_to_us( ms ) return ms * 1000 end


--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	gluafuncbudget
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
gluafuncbudget = {}

local Queue = {}
local Results = {}

local Default_FuncBudget_Frames = 500
local Default_FuncBudget_Iterations = 100000
local Default_FuncBudget_MeasureUnit = ( { 'sec'; 'ms'; 'us' } )[2]
local Default_FuncBudget_Digit = 5
local Default_FuncBudget_ComparisonBasis = ( { 'median'; 'min'; 'max'; 'average' } )[4]
local Default_FuncBudget_ShownMetrics = 'median min max average stddev avgfps'
local Default_FuncBudget_JITOffAll = false

local FuncBudget_Frames = Default_FuncBudget_Frames
local FuncBudget_Iterations = Default_FuncBudget_Iterations
local FuncBudget_Digit = Default_FuncBudget_Digit
local FuncBudget_MeasureUnit = Default_FuncBudget_MeasureUnit
local FuncBudget_ComparisonBasis = Default_FuncBudget_ComparisonBasis
local FuncBudget_ShownMetrics = Default_FuncBudget_ShownMetrics
local FuncBudget_JITOffAll = Default_FuncBudget_JITOffAll

local FuncBudget_Standard_Last = 0

local L_Metric = {

	median = 'Median';
	min = 'Min';
	max = 'Max';
	average = 'Average';
	stddev = 'StdDev';
	avgfps = 'AvgFPS'

}

local g_iPreviousGCStepMul

--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	Purpose: Configures the utility
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
function gluafuncbudget.Configure( tGLuaFuncBudgetParams )

	local params = tGLuaFuncBudgetParams

	FuncBudget_Frames            = params.frames                or Default_FuncBudget_Frames
	FuncBudget_Iterations        = params.iterations_per_frame  or Default_FuncBudget_Iterations
	FuncBudget_MeasureUnit       = params.measure_unit          or Default_FuncBudget_MeasureUnit
	FuncBudget_Digit             = params.digit                 or Default_FuncBudget_Digit
	FuncBudget_ComparisonBasis   = params.comparison_basis      or Default_FuncBudget_ComparisonBasis
	FuncBudget_ShownMetrics      = params.shown_metrics         or Default_FuncBudget_ShownMetrics
	FuncBudget_JITOffAll         = params.jit_off_all           or Default_FuncBudget_JITOffAll

	MsgC( GRAY, '\n', string.rep( '-', 72 ) )
	MsgC( WHITE, '\nGLuaFuncBudget Configuration:' )

	if ( params.usercpu ) then
		MsgC( WHITE, '\n\tUser CPU: ',        YELLOW,    params.usercpu )
	end

	MsgC( WHITE, '\n\tOS: ',                  YELLOW,    jit.os )
	MsgC( WHITE, '\n\tBranch: ',              YELLOW,    BRANCHSHORT, GRAY, '; ', YELLOW, jit.arch, GRAY, '; ', YELLOW, jit.version, GRAY, ' (', YELLOW, table.concat( { jit.status() }, ' ', 2 ), GRAY, ')' )

	MsgC( WHITE, '\n\tRealm: ',               COL_REALM, REALMSTR )
	MsgC( WHITE, '\n\tFrames: ',              GRAY,      string.Comma( FuncBudget_Frames ) )
	MsgC( WHITE, '\n\tIterations/frame: ',    GRAY,      string.Comma( FuncBudget_Iterations ) )
	MsgC( WHITE, '\n\tMeasure Unit: ',        RED,       FuncBudget_MeasureUnit )
	MsgC( WHITE, '\n\tDigit: ',               GRAY,      FuncBudget_Digit )
	MsgC( WHITE, '\n\tComparison Basis: ',    DARKAQUA,  FuncBudget_ComparisonBasis )
	MsgC( WHITE, '\n\tShown Metrics: ',       GRAY,      FuncBudget_ShownMetrics )
	Msg( '\n' )

end

--[[ Doc
	Structure: GLuaFuncBudgetParams
		Description
		—————————————————————————————————————
			The configuration-structure for the utility.

		Members
		—————————————————————————————————————
			string usercpu
				Convenience and/or transparency purpose. Put your one for descriptiveness' sake. Optional.

			number frames
				The number of frames for the budgeting of functions.

				A point of reference:
					The more frames => the more comprehensive the result is.
					The less frames => the more varying the result is.

					"Precision" is likely to be an inapplicable term here,
					for if to take calculations, they're already precise,
					so what exactly is supposed to get more precise? I — dunno.

					Consider taking 25, 50, 100, 250, 500, 1 000.

			number iterations_per_frame
				The number of iterations of a budgeted-function within a frame.
				Consider taking 10 000, 100 000, 1 000 000, 10 000 000.

			string measure_unit
				One of: sec, ms, us.

			number digit
				The amount of shown digits after the decimal point of metrics' values.

			string comparison_basis
				The metric by which budgeted-functions will be compared.
				One of: median, min, max, average.

			string shown_metrics
				Any combination of: median, min, max, average, stddev, avgfps.

			boolean jit_off_all
				Convenience purpose. For turning off JIT for every test at once. Optional.
]]


--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	adjust_time_spent
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
local function adjust_time_spent( t )

	if ( FuncBudget_MeasureUnit == 'sec' ) then return ms_to_sec( t ) end
	if ( FuncBudget_MeasureUnit == 'us' ) then return ms_to_us( t ) end

	return t

end

--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	Purpose: (Internal) Budgets the passed budgeted-function
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
local UTIL_TimerCycle = util.TimerCycle

local function BudgetFunction( tBudgetedFunc )

	local budgetedfunc = tBudgetedFunc

	local arg1, arg2, arg3, arg4, arg5, arg6, arg7
	local pfnPre = budgetedfunc.pre

	if ( pfnPre ) then
		arg1, arg2, arg3, arg4, arg5, arg6, arg7 = pfnPre( budgetedfunc )
	end

	local name = budgetedfunc.name
	local pfnMain = budgetedfunc.main

	local success, err = pcall( pfnMain, arg1, arg2, arg3, arg4, arg5, arg6, arg7 )

	if ( not success ) then
		return MsgC( WHITE, '\nBudgeted-function ', YELLOW, name, WHITE, ' has failed:\n\t', RED, err, '\n' )
	end

	--
	-- Start
	--
	local funcbudget = {

		m_TimeSpentHistory = {};
		m_FrameRateHistory = {};

		pBudgetedFunc = budgetedfunc

	}

	table.insert( Results, funcbudget )

	budgetedfunc.jit_off = budgetedfunc.jit_off or FuncBudget_JITOffAll

	if ( budgetedfunc.jit_off ) then
		jit.off( pfnMain )
	else
		jit.on( pfnMain )
	end

	-- More info on arguments for jit.off|on|flush here: https://luajit.org/ext_jit.html

	-- Flush it's compiled code
	jit.flush( pfnMain, true )

	-- Warm it up
	pfnMain( arg1, arg2, arg3, arg4, arg5, arg6, arg7 )

	for frame = 1, FuncBudget_Frames do

		local t = 0.0

		if ( FuncBudget_Iterations > 1 ) then

			UTIL_TimerCycle()

				for i = 1, FuncBudget_Iterations do
					pfnMain( arg1, arg2, arg3, arg4, arg5, arg6, arg7 )
				end

			t = UTIL_TimerCycle()

		else

			UTIL_TimerCycle()

				pfnMain( arg1, arg2, arg3, arg4, arg5, arg6, arg7 )

			t = UTIL_TimerCycle()

		end

		funcbudget.m_TimeSpentHistory[frame] = adjust_time_spent( t )
		funcbudget.m_FrameRateHistory[frame] = 1 / ms_to_sec( t )

		collectgarbage()
		collectgarbage()

	end

	local pfnPost = budgetedfunc.post

	if ( pfnPost ) then
		pfnPost()
	end

end


--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	Purpose: (Internal) Calculates, formats, prints, and flushes the results
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
local ipairs = ipairs

local function FinishBudgeting()

	for index, funcbudget in ipairs( Results ) do

		local historyTimeSpent = funcbudget.m_TimeSpentHistory
		local historyFrameRate = funcbudget.m_FrameRateHistory

		local budgetedfunc = funcbudget.pBudgetedFunc

		--
		-- Calculate
		--
		local flMedian = calculate_median( historyTimeSpent )
		local flMin = find_minimal( historyTimeSpent )
		local flMax = find_maximal( historyTimeSpent )
		local flAvg = calculate_mean( historyTimeSpent )

		local flStdDev; do

			local flDeviationSquared = 0

			for frame = 1, FuncBudget_Frames do

				local val = ( historyTimeSpent[frame] - flAvg )
				flDeviationSquared = ( flDeviationSquared + ( val * val ) )

			end

			local variance = ( flDeviationSquared / FuncBudget_Frames )
			flStdDev = math.sqrt( variance )

		end

		local flAvgFrameRate = calculate_mean( historyFrameRate )

		local numCompetitor = ( {

			median = flMedian;
			min = flMin;
			max = flMax;
			average = flAvg

		} )[FuncBudget_ComparisonBasis]

		local flPercent = 100.0

		if ( budgetedfunc.standard ) then
			FuncBudget_Standard_Last = numCompetitor
		else
			flPercent = ( ( numCompetitor * 100 ) / FuncBudget_Standard_Last )
		end

		--
		-- Format & Print
		--
		local colState = budgetedfunc.jit_off and GRAY or GREEN
		local stateJIT = budgetedfunc.jit_off and 'OFF' or 'ON'

		MsgC(
			WHITE, '\nBudgeted-function (', COL_JIT, 'JIT ', colState, stateJIT, WHITE, '): ',
			YELLOW, budgetedfunc.name, ' ', WHITE, '(', DARKAQUA, Format( '%g%%', flPercent ), WHITE, ')'
		)

		local toshow = string.Explode( ' ', FuncBudget_ShownMetrics )

		local fmt_fl = ( '%.' .. FuncBudget_Digit .. 'f' )

		local numbers = {

			median = Format( fmt_fl, flMedian );
			min = Format( fmt_fl, flMin );
			max = Format( fmt_fl, flMax );
			average = Format( fmt_fl, flAvg );
			stddev = Format( fmt_fl, flStdDev );
			avgfps = Format( '%i', flAvgFrameRate )

		}

		Msg( '\n\t' )

		for _, name in ipairs( toshow ) do

			local spaceadjustment = string.rep( ' ', #numbers[name] - #name )
			MsgC( WHITE, L_Metric[name], ' ', spaceadjustment )

		end

		Msg( '\n\t' )

		for _, name in ipairs( toshow ) do

			local spaceadjustment = string.rep( ' ', #name - #numbers[name] )
			MsgC( GRAY, numbers[name], ' ', spaceadjustment )

		end

		MsgC( WHITE, '\n' )

		-- Flush
		Results[index] = nil

	end

	collectgarbage( 'setstepmul', g_iPreviousGCStepMul )

end


--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	Purpose: (Internal) Runs function-budgeting
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
local function RunFunctionBudgeting()

	BudgetFunction( table.remove( Queue, 1 ) )

	if ( #Queue == 0 ) then
		FinishBudgeting()
	else
		RunFunctionBudgeting()
	end

end

--[[–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
	Purpose: Queues the passed budgeted-function
–––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––]]
function gluafuncbudget.Queue( tBudgetedFunc )

	table.insert( Queue, tBudgetedFunc )

	timer.Create( 'gluafuncbudget', 0.1, 1, function()

		for i = 1, #Queue do
			if ( Queue[i].standard ~= nil ) then goto moveon end
		end

		Queue[1].standard = true

		::moveon::

		collectgarbage()
		collectgarbage()
		collectgarbage( 'stop' )
		g_iPreviousGCStepMul = collectgarbage( 'setstepmul', 10000 ) -- Keep the garbage collector at bay for a time
		collectgarbage()
		collectgarbage()

		local T = 0

		while ( true ) do

			T = T + 1
			if ( T > 1e6 ) then break end

		end

		RunFunctionBudgeting()

	end )

end

--[[ Doc
	Structure: BudgetedFunc
		Description
		—————————————————————————————————————
			The datum-structure for a function to be budgeted.

		Members
		—————————————————————————————————————
			string name
				This case's name.

			boolean standard
				Use this case's result as the current comparison standard for the next tests?
				If omitted everywhere, the first case will be marked as standard.
				Optional though recommended.

			function pre
				Pre-main function. Optional.

				Function Arguments:
					1. table — self

				Function Returns:
					1. vararg ...[0;7] — optional arguments to pass to `main`

			function main
				Function to be budgeted.

				Function Arguments:
					[1;7]: any — values returned by `pre`

			boolean jit_off
				Disable JIT for this exact function? Optional.

			function post
				Post-main function. Optional.
]]
