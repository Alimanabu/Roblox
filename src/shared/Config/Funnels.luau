-- Step names of the funnels shown in Creator Hub -> Analytics -> Funnels.
-- The names are permanent: renaming a step splits its history in two. Short, English, at most 50 characters.
-- New steps are only added at the end.

local Funnels = {}

-- Tutorial funnel (LogOnboardingFunnelStepEvent): step 1 = joined the game, then one step for every
-- finished step of Config/Tutorial, in the same order. Names[n] is the name of funnel step n.
Funnels.ONBOARDING = { "Joined", "Step1_craft", "Step2_craft", "Step3_upgrade", "Step4_lock", "Step5_daily" }

-- Main loop funnel (LogFunnelStepEvent), one funnelSessionId per player for life.
Funnels.LOOP_NAME = "MainLoop"
-- key is the fact in the profile (funnel.done[key]); the step goes out only after all previous ones.
Funnels.LOOP = {
	{ key = "capsule", name = "FirstCapsule" }, -- opened the first capsule (first brainrot)
	{ key = "fuse", name = "FirstFuse" }, -- fused the first brainrot
	{ key = "sell", name = "FirstSale" }, -- sold the first brainrot
	{ key = "upgrade", name = "FirstUpgrade" }, -- bought the first upgrade
	{ key = "saved", name = "ProgressSaved" }, -- the first successful write to the DataStore
	{ key = "returned", name = "ReturnedDay2" }, -- joined on a later UTC day than the last visit
}

return Funnels
