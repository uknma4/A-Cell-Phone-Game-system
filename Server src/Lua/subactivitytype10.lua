module("subactivitytype10", package.seeall)
 
--[[
data define:
    totalVal 累计充值金额
    count    已抽奖次数
    status   1表示有领取领取，nil表示没有奖励领取且下一步是抽奖
    index    最新中奖索引，nil表示没抽过
global define:
    count 记录条数
    name   玩家名字
    times  中奖倍数
    money  中奖金额
}
--]]

local subType = 10

--下发数据
local function writeRecord(npack, record, conf, id, actor)
    if nil == record then record = {} end
    LDataPack.writeInt(npack, record.count or 0)
    LDataPack.writeInt(npack, record.totalVal or 0)
    LDataPack.writeInt(npack, record.index or 0)
    LDataPack.writeByte(npack, record.status or 0)

    local gdata = activitysystem.getGlobalVar(id)
    local count = #(gdata.record or {})

    LDataPack.writeChar(npack, count)
    for _,v in ipairs(gdata.record or {}) do
        LDataPack.writeString(npack, v.name or "")
        LDataPack.writeDouble(npack, v.times or 0)
        LDataPack.writeInt(npack, v.money or 0)
    end
end

local function onReCharge(id, conf)
    return function(actor, val)
        if activitysystem.activityTimeIsEnd(id) then return end

        local var = activitysystem.getSubVar(actor, id)
        var.totalVal = (var.totalVal or 0) + val         --最新的充值金额

        activitysystem.sendActivityData(actor, id)
    end
end

--检测是否需要公告
local function checkNotice(actor, cfg, id, times)
    local money = math.ceil((cfg.yuanBao or 0) * times)
    if cfg.noticeId then --公告和记录日志
        if (cfg.noticeId.multiple or 0) <= times then
            local name = LActor.getName(actor)

            noticemanager.broadCastNotice(cfg.noticeId.id, name, times, money)

            --全局变量
            local gdata = activitysystem.getGlobalVar(id)
            if not gdata.record then gdata.record = {} end
            table.insert(gdata.record, {name=name, times=times, money=money})

            if #gdata.record > 20 then table.remove(gdata.record, 1) end
        else
            LActor.sendTipmsg(actor, string.format(LAN.FUBEN.hdcj1, tostring(money)), ttScreenCenter)
        end
    end
end

--获取中奖索引
local function getRewardIndex(config)
    local pre = math.random(10000)
    local total = 0
    for index, data in ipairs(config.info or {}) do
        total = total + data.value
        if total >= pre then return index end
    end

    return 0
end

local function giveRewards(actor, id, record, conf)
	local cfg
     --获取中奖信息
	if (record.count==nil) then
	record.count=0
	end
	 if (record.count>=4) then
	   cfg = conf[(4 or 0) + 1]
	else
      cfg = conf[(record.count or 0) + 1]
	end
    local info = cfg.info[record.index or 0]
    if not info then
        print("subactivitytype10.getReward:info nil, count:"..tostring(record.index)..", actorId:"..tostring(actorId))
        return
    end

    LActor.changeYuanBao(actor, cfg.yuanBao * info.multiple, "type10 "..tostring(record.count or 0))
    record.status = nil
	
    record.count = (record.count or 0) + 1

    --公告
    checkNotice(actor, cfg, id, info.multiple)

    activitysystem.sendActivityData(actor, id)
end

GMulYBcount={}
 
--请求领取奖励
local function getReward(id, typeconfig, actor, record, packet)
    local actorId = LActor.getActorId(actor)
    local conf = typeconfig[id]
    if nil == conf then
        print("subactivitytype10.getReward:conf is nil, id:"..tostring(id)..", actorId:"..tostring(actorId))
        return
    end
	 
     if (activitysystem.GisOpenMltYB[LActor.getName(actor)].isOpenMltYB==0) then
	 record.status = nil
   
	 activitysystem.sendActivityData(actor, id)
	  return
	 end
	 if (record.count==nil) then
	record.count=0
	end
    if 1 == (record.status or 0) then  --领取奖励
	
        giveRewards(actor, id, record, conf)
    else    --抽奖
        --是否大于最大抽奖次数
        local count = record.count or 0
       -- if not conf[count+1] then print("subactivitytype10.getReward:count overflow, count:"..tostring(count)..", actorId:"..tostring(actorId)) return end
      --随机count 
	local isCloseMltYB=0
	     if (not GMulYBcount[LActor.getName(actor)] or (GMulYBcount[LActor.getName(actor)].MulYBcount==nil)) then
          GMulYBcount[LActor.getName(actor)]={MulYBcount=subactivitytype9.mulYBturntableCount()}
		 --print("eddie 初始化 record.count")
		 if (record.count>0) then
		  record.count=0 --初始化record.count再重启服务时GMulYBcount.actor.MulYBcount==0但是record.count还保存着上一次的值所以初始化
		  count=0
          --print("eddie 初始化 record.count 成功")
          end
		 end
	    if GMulYBcount[LActor.getName(actor)].MulYBcount==0 then
		 if (record.count>0) then
		  record.count=0 --初始化record.count再重启服务时GMulYBcount.actor.MulYBcount==0但是record.count还保存着上一次的值所以初始化
		 end
	   GMulYBcount[LActor.getName(actor)].MulYBcount=subactivitytype9.mulYBturntableCount()
		 
		end
 
	    print("GMulYBcount:"..GMulYBcount[LActor.getName(actor)].MulYBcount.." count:"..count+1)
	    if count+1>=GMulYBcount[LActor.getName(actor)].MulYBcount then
		--print("subactivitytype10.getReward:count overflow, count,GMulYBcount:"..tostring(count)..", actorId:"..tostring(actorId)..", GMulYBcount:"..GMulYBcount.actor.MulYBcount)
		isCloseMltYB=1
		 
		GMulYBcount[LActor.getName(actor)].MulYBcount=0
		record.count=0
		activitysystem.GisOpenMltYB[LActor.getName(actor)].isOpenMltYB=0
	      
		end
	
      --[[  --判断金额满足条件
        if conf[count+1].recharge > (record.totalVal or 0) then
            print("subactivitytype10.getReward:money not enough, money:"..tostring(record.totalVal or 0)..", actorId:"..tostring(actorId))
            return
        end
--]]
        --扣元宝不算入其它元宝活动
		local confIndex
      if count + 1 > 5 then
      confIndex = 5
      else
      confIndex = count + 1
      end
	    if conf[confIndex].item and LActor.getItemCount(actor, conf[confIndex].item) > 0 then
				LActor.costItem(actor, conf[confIndex].item, 1, "type10 once"..id)
        else
           LActor.changeYuanBao(actor, -conf[confIndex].yuanBao, "type10 "..tostring(record.count or 0), true)
        end
        --扣钱
        --LActor.changeCurrency(actor, NumericType_YuanBao, -conf[count+1].yuanBao, "type10cost:"..tostring(count+1))

        --获取中奖索引，用于发放奖励
		  if (count+1)>5 then
		record.index = getRewardIndex(conf[5])
	      else
        record.index = getRewardIndex(conf[count+1])
	      end
        if 0 == (record.index or 0) then print("subactivitytype10.getReward:index 0, id:"..tostring(count+1)..", actorId:"..tostring(actorId)) return end

        --保存可以领取奖励的标识
        record.status = 1

        activitysystem.sendActivityData(actor, id,isCloseMltYB)
    end
end

--下线补发奖励
local function onLogout(id, conf)
    return function(actor)
        local record = activitysystem.getSubVar(actor, id)
        if 1 == (record.status or 0) then giveRewards(actor, id, record, conf) end
    end
end

local function initFunc(id, conf)
    actorevent.reg(aeUserLogout, onLogout(id, conf))
    actorevent.reg(aeRecharge, onReCharge(id, conf))
end

subactivities.regConf(subType, ActivityType10Config)
subactivities.regInitFunc(subType, initFunc)
subactivities.regWriteRecordFunc(subType, writeRecord)
subactivities.regGetRewardFunc(subType, getReward)
