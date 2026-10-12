-- 新增主词时间属性。共享的是显式配置值，表在运行时按静态数据只读。
-- 两小时日常 profile 不借用整夜睡眠；遗忘已形成的记忆变化不随药效结束自动恢复。
-- 每个可被采样的标签都在 RESIDUAL_RULES 中明确声明，不按未知标签自动补表。

local SPEED_TO_DELAY_HOURS = {
    { delayHours = 2, speed = 0 },
    { delayHours = 1, speed = 2 },
    { delayHours = 0, speed = 4 },
}

local RESIDUAL_POINTS = {
    { ratio = 0.6, hoursAfterEnd = 0 },
    { ratio = 0.3, hoursAfterEnd = 1 },
    { ratio = 0.1, hoursAfterEnd = 2 },
    { ratio = 0.05, hoursAfterEnd = 3 },
    { ratio = 0, hoursAfterEnd = 4 },
}

local RESIDUAL_RULES = {
    { effectId = "sleep", points = RESIDUAL_POINTS },
    { effectId = "dream", points = RESIDUAL_POINTS },
    { effectId = "calm", points = RESIDUAL_POINTS },
    { effectId = "happy", points = RESIDUAL_POINTS },
    { effectId = "brave", points = RESIDUAL_POINTS },
    { effectId = "forget", points = RESIDUAL_POINTS },
    { effectId = "recall", points = RESIDUAL_POINTS },
    { effectId = "appetite", points = RESIDUAL_POINTS },
    { effectId = "steady", points = RESIDUAL_POINTS },
    { effectId = "anger", points = RESIDUAL_POINTS },
    { effectId = "sadness", points = RESIDUAL_POINTS },
    { effectId = "confusion", points = RESIDUAL_POINTS },
    { effectId = "reason", points = RESIDUAL_POINTS },
    { effectId = "relax", points = RESIDUAL_POINTS },
    { effectId = "fear", points = RESIDUAL_POINTS },
    { effectId = "safety", points = RESIDUAL_POINTS },
    { effectId = "trust", points = RESIDUAL_POINTS },
    { effectId = "suspicion", points = RESIDUAL_POINTS },
    { effectId = "envy", points = RESIDUAL_POINTS },
    { effectId = "curiosity", points = RESIDUAL_POINTS },
    { effectId = "pain", points = RESIDUAL_POINTS },
    { effectId = "warmth", points = RESIDUAL_POINTS },
}

return {
    {
        id = "daytime_basic",
        desc = "非睡眠日常主词的短效调试值，基础两小时",
        baseDurationHours = 2, durationHoursPerPoint = 1, recoveryAfterEndHours = 0,
        speedToDelayHours = SPEED_TO_DELAY_HOURS,
        residualRules = RESIDUAL_RULES,
    },
    {
        id = "dream_basic",
        desc = "梦：基础六小时；实际入睡后才产生梦境经历",
        baseDurationHours = 6, durationHoursPerPoint = 1, recoveryAfterEndHours = 0,
        speedToDelayHours = SPEED_TO_DELAY_HOURS,
        residualRules = RESIDUAL_RULES,
    },
    {
        id = "warmth_basic",
        desc = "温暖：基础四小时，不授予耐寒或防火",
        baseDurationHours = 4, durationHoursPerPoint = 1, recoveryAfterEndHours = 0,
        speedToDelayHours = SPEED_TO_DELAY_HOURS,
        residualRules = RESIDUAL_RULES,
    },
    {
        id = "pain_basic",
        desc = "疼：基础一小时，不当作治疗",
        baseDurationHours = 1, durationHoursPerPoint = 1, recoveryAfterEndHours = 0,
        speedToDelayHours = SPEED_TO_DELAY_HOURS,
        residualRules = RESIDUAL_RULES,
    },
}
