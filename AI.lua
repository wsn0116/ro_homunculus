
require "./AI/Const.lua"
require "./AI/Util.lua"

-- 状態定数
STATE_IDLE		= 0
STATE_FOLLOW	= 1
STATE_CHASE		= 2
STATE_ATTACK	= 3

-----------------------------------------------------------------------------
-- 設定
-----------------------------------------------------------------------------

-- 主人の追跡を開始する距離（ｎマス）
DISTANCE_FOLLOW_OWNER_NORMAL = 5
DISTANCE_FOLLOW_OWNER_ATTACK = 8

-- ターゲットとする敵との距離（主人からｎマス）
DISTANCE_TARGET_MOB = 5

-- スキル発動のための前提 SP 残量（ｎ％）
USE_SKILL_PERCENTAGE = 35

-- 攻撃スキル（カプリス）
USE_ATTACK_SKILL_ID = 8013
USE_ATTACK_SKILL_LV = 5

-- 回復スキル（カオティックベネディクション）
USE_SUPPORT_SKILL_ID = 8014
USE_SUPPORT_SKILL_LV = 4

-- カプリス
SKILL_CAPRICE             = 8013
-- カオティックベネディクション
SKILL_CHAOTIC_VENEDICTION = 8014
-- チェンジインストラクション
SKILL_CHANGE_INSTRUCTION  = 8015
-- バイオエクスプロージョン
SKILL_BIO_EXPLOSION       = 8016

-- 先攻区分（true : アクティブ, false : パッシブ）
INTERSECT = false

-----------------------------------------------------------------------------
-- 変数初期化
-----------------------------------------------------------------------------

-- 現在の状態
m_CurrentState = STATE_IDLE

-- 現在の移動先
m_DestX = 0
m_DestY = 0

-- 現在の使用スキル
m_SkillId = 0
m_SkillLv = 0

-- 現在の敵
m_EnemyId = 0

-- 直前の敵
m_PreviousEnemyId = 0

-- 予約コマンド用リストオブジェクト生成
m_ResCmdList = List.new()

-----------------------------------------------------------------------------
-- さぶるーちん
-----------------------------------------------------------------------------

-- 主人追跡
function FollowOwner(myid)

	local dist

	-- 閾値判断
	if (m_CurrentState == STATE_CHASE or m_CurrentState == STATE_ATTACK) then
		dist = DISTANCE_FOLLOW_OWNER_ATTACK
	else
		dist = DISTANCE_FOLLOW_OWNER_NORMAL
	end

	-- 閾値より離れていたら追跡
	local owner_id = GetV(V_OWNER, myid)
	if (GetDistanceFromOwner(myid) > dist) then
		-- 主人が移動している
		if (GetV(V_MOTION, owner_id) == MOTION_MOVE) then
			-- イベント発生時の主人位置へ移動
			local owner_x, owner_y = GetV(V_POSITION, owner_id)
			-- MoveToOwner だと移動が不自然なので Move を使う
			Move(myid, owner_x, owner_y)
		else
			-- 主人の下へまっしぐら
			MoveToOwner(myid)
		end

		TraceAI("FollowOwner : " .. m_CurrentState .. " -> STATE_FOLLOW")
		m_CurrentState = STATE_FOLLOW
		return true
	else
		return false
	end

end

-- 敵はいるか
function HasEnemy()

	if (m_EnemyId == 0) then
		TraceAI("EventChaseEnemy : " .. m_CurrentState .. " -> STATE_IDLE")
		m_CurrentState = STATE_IDLE
		return false
	else
		return true
	end

end

-- 敵と認識し、追跡を開始する
function RecognizeEnemy(v, reason)

	-- 敵をセット
	m_EnemyId = v

	-- 前回の敵をクリア
	m_PreviousEnemyId = 0

	-- 追跡
	TraceAI("RecognizeEnemy : " .. m_CurrentState .. " -> STATE_CHASE (" .. reason .. ")")
	m_CurrentState = STATE_CHASE

end

-- 索敵処理
function SearchEnemy(myid)

	local i = 1
	local enemies = {}
	local actors = GetActors()

	-- まず敵だけを配列に格納
	for u, v in ipairs(actors) do
		-- 主人と自分以外
		if (v ~= GetV(V_OWNER, myid) and v ~= myid) then
			-- モンスターだ！
			if (IsMonster(v) == 1)	then
				-- 前回追跡を諦めた敵ではないか（同じ敵を二度追跡しない）
				if (m_PreviousEnemyId ~= v) then
					enemies[i] = v
					i = i + 1
				end
			end
		end
	end

	-- 主人をターゲットとしている敵はいるか
	for u, v in ipairs(enemies) do
		if (GetV(V_TARGET, v) == GetV(V_OWNER, myid)) then
			-- 敵と認定し追跡
			RecognizeEnemy(v, "Target owner")
			return
		end
	end

	--  自分をターゲットとしている敵はいるか
	for u, v in ipairs(enemies) do
		-- 自分を攻撃目標としているか
		if (GetV(V_TARGET, v) == myid) then
			-- 敵と認定し追跡
			RecognizeEnemy(v, "Target me")
			return
		end
	end

	-- 主人「が」ターゲットとしている敵はいるか
	for u, v in ipairs(enemies) do
		if (GetV(V_TARGET, GetV(V_OWNER, myid)) == v) then
			-- 敵と認定し追跡
			RecognizeEnemy(v, "Owner is attacking")
			return
		end
	end

	-- ほかに敵はいるか（アクティブ設定時のみ）
	if (INTERSECT == true) then
		for u, v in ipairs(enemies) do
			-- その見つけたモンスターは主人から DISTANCE_TARGET_MOB マス以内か
			if (GetDistanceFromOwner(myid) <= DISTANCE_TARGET_MOB) then
				-- 前回追跡を諦めた敵ではないか（同じ敵を二度追跡しない）
				if (m_PreviousEnemyId ~= v) then
					-- 敵と認定し追跡
					RecognizeEnemy(v, "Near me")
					return
				end
			end

			-- テリトリー外なので無視
			m_EnemyId = 0
		end
	end

	-- 周囲に敵がおらず、自分の SP が十分あって、かつ HP が減っていたら回復する
	local cur_hp_per = GetV(V_HP, myid) / GetV(V_MAXHP, myid) * 100
	local cur_sp_per = GetV(V_SP, myid) / GetV(V_MAXSP, myid) * 100
	local judge_per = math.random(100)
	if (cur_hp_per < 100) and (cur_sp_per > USE_SKILL_PERCENTAGE) then
		if (cur_sp_per > judge_per) then
			SkillObject(myid, USE_SUPPORT_SKILL_LV, USE_SUPPORT_SKILL_ID, myid)
		end
	end

	-- 敵がいなかったらアイドル状態へ移行する
	m_CurrentState = STATE_IDLE
	TraceAI("EventIdle : STATE_IDLE -> STATE_IDLE")

end

-----------------------------------------------------------------------------
-- 状態毎処理
-----------------------------------------------------------------------------

-- アイドル
function EventIdle(myid)

	-- 近くに主人がいなかったら追いかける
	if (FollowOwner(myid, m_CurrentState) == true) then
		return
	end

	-- 予約コマンドがあれば実行する
	local msg = List.popleft(m_ResCmdList)
	if (msg ~= nil) then
		-- 予約コマンド処理
		ProcessCommand(myid, msg)
		return 
	end

	-- 索敵する
	SearchEnemy(myid)

end

-- 主人追跡
function EventFollow(myid)

	-- 近くに主人がいなかったら追いかける
	if (FollowOwner(myid) == true) then
		return
	else
		m_CurrentState = STATE_IDLE
		TraceAI("EventFollow : STATE_FOLLOW -> STATE_IDLE")
	end

end

-- 敵追跡
function EventChaseEnemy(myid)

	-- 近くに主人がいなかったら主人を追いかける（深追い防止）
	if (FollowOwner(myid) == true) then
		-- 諦めた敵を覚えておく
		m_PreviousEnemyId = m_EnemyId
		return
	end

	-- 敵はいるか
	if (HasEnemy() == false) then
		return
	end

	-- 敵は死んだｗ
	if (GetV(V_MOTION, m_EnemyId) == MOTION_DEAD) then
		m_EnemyId = 0
		m_CurrentState = STATE_IDLE
		TraceAI("EventChaseEnemy : STATE_CHASE -> STATE_IDLE")
		return
	end

	-- 敵との距離
	local dist = GetDistance2(myid, m_EnemyId)
	-- 射程導出
	local attack_range = GetV(V_ATTACKRANGE, myid)

	-- 攻撃判断
	if (attack_range >= dist) then
		-- 射程内なら攻撃
		m_CurrentState = STATE_ATTACK
		TraceAI("EventChaseEnemy : STATE_CHASE -> STATE_ATTACK")
	else
		-- 射程外, 敵に到達しているか
		local enemy_x, enemy_y = GetV(V_POSITION, m_EnemyId)
		-- 敵に追いついていないなら追跡続行
		if (m_DestX ~= enemy_x or m_DestY ~= enemy_y) then
			m_DestX = enemy_x
			m_DestY = enemy_y
			Move(myid, enemy_x, enemy_y)
			m_CurrentState = STATE_CHASE
			TraceAI("EventChaseEnemy : STATE_CHASE -> STATE_CHASE")

		-- 行き先に敵がいないときは再索敵する
		else
			m_EnemyId = 0
			m_DestX = 0
			m_DestY = 0
			m_CurrentState = STATE_IDLE
			TraceAI("EventChaseEnemy : STATE_CHASE -> STATE_IDLE")
		end
	end

end

-- 敵殲滅
function EventAttackEnemy(myid)

	-- 近くに主人がいなかったら主人を追いかける
	if (FollowOwner(myid) == true) then
		return
	end

	-- 敵はいるか
	if (HasEnemy() == false) then
		return
	end

	-- 敵は死んだ
	if (GetV(V_MOTION, m_EnemyId) == MOTION_DEAD) then
		m_EnemyId = 0
		m_CurrentState = STATE_IDLE
		TraceAI("EventAttackEnemy : STATE_ATTACK -> STATE_IDLE")
		return
	end

	-- 敵との距離
	local my_x, my_y = GetV (V_POSITION, myid)
	local enemy_x, enemy_y = GetV(V_POSITION, m_EnemyId)
	local dist = GetDistance (my_x, my_y, enemy_x, enemy_y)
	-- 射程導出
	local attack_range = GetV(V_ATTACKRANGE, myid)

	-- 射程内なら攻撃する
	if (attack_range >= dist) then
		-- コマンドによる指示があるか
		if (m_SkillId == 0 and m_SkillLv == 0) then
			-- 攻撃方法判定（残り SP 導出）
			local cur_sp_per = GetV(V_SP, myid) / GetV(V_MAXSP, myid) * 100
			if (cur_sp_per < USE_SKILL_PERCENTAGE) then
				-- SP が残り少ないときは物理攻撃だけ
				Attack (myid, m_EnemyId)
			else
				local judge_per = math.random(100)
				TraceAI("Skill Judge : " .. cur_sp_per .. " <= " .. judge_per)
				-- SP が USE_SKILL_PERCENTAGE % 以上あるときはスキル使用判定
				if (cur_sp_per <= judge_per) then
					-- 物理攻撃
					Attack (myid, m_EnemyId)
				else
					-- スキル攻撃
					SkillObject(myid, USE_ATTACK_SKILL_LV, USE_ATTACK_SKILL_ID, m_EnemyId)
				end
			end
		else
			-- コマンドによるスキル使用
			SkillObject(myid, m_SkillLv, m_SkillId, m_EnemyId)
			TraceAI("EventAttackEnemy : Used skill by command")
		end

		-- 使用スキル予約情報をリセット
		m_SkillLv = 0
		m_SkillId = 0

		m_CurrentState = STATE_ATTACK
		TraceAI("EventAttackEnemy : STATE_ATTACK -> STATE_ATTACK")
	else
		-- 射程外ならあきらめる
		m_EnemyId = 0
		m_CurrentState = STATE_IDLE
		TraceAI("EventAttackEnemy : STATE_ATTACK -> STATE_IDLE")
	end

end

-----------------------------------------------------------------------------
-- 入力コマンド処理
-----------------------------------------------------------------------------

-- 待機
function CmdIdle(myid)
	m_CurrentState = STATE_IDLE
	TraceAI("CmdIdle : STATE_IDLE")
end

-- 移動
function CmdMove(myid, x, y)
	-- 言われた通りに移動する
	Move(myid, x, y)
end

-- 攻撃
function CmdAttack(myid, target_id)
	-- ターゲットをセット
	m_EnemyId = target_id

	-- まず目標を追跡する
	m_CurrentState = STATE_CHASE
	TraceAI("CmdAttack : STATE_CHASE")
end

-- スキル攻撃
function CmdSkillAttack(myid, skill_lv, skill_id, target_id)
	-- ターゲットをセット
	m_EnemyId = target_id

	-- 使用スキル予約情報をセット
	m_SkillLv = skill_lv
	m_SkillId = skill_id

	-- まず目標を追跡する
	m_CurrentState = STATE_CHASE
	TraceAI("CmdAttack : STATE_CHASE")
end

-----------------------------------------------------------------------------
-- 状態遷移処理
-----------------------------------------------------------------------------
function ProcessCommand(myid, msg)

	-- 待機
	if (msg[1] == HOLD_CMD) then
		CmdIdle(myid)
	end

	-- 移動
	if (msg[1] == MOVE_CMD) then
		CmdMove(myid, msg[2], msg[3])
	end

	-- 攻撃
	if (msg[1] == ATTACK_OBJECT_CMD) then
		CmdAttack(myid, msg[2])
	end

	-- スキル使用
	if (msg[1] == SKILL_OBJECT_CMD) then
		CmdSkillAttack(myid, msg[2], msg[3], msg[4])
	end

end

-----------------------------------------------------------------------------
-- AI メイン
-----------------------------------------------------------------------------
function AI(myid)

	-- 通常コマンド
	local msg = GetMsg (myid)
	-- 予約コマンド
	local rmsg = GetResMsg (myid)

	-- コマンド処理
	if msg[1] == NONE_CMD then
		-- 通常コマンドがないときは、予約コマンドを処理する
		if rmsg[1] ~= NONE_CMD then
			if List.size(m_ResCmdList) < 10 then
				-- 予約コマンド保存
				List.pushright(m_ResCmdList, rmsg)
			end
		end
	else
		-- 新しいコマンドが入力されたら、予約コマンドは削除する
		List.clear (m_ResCmdList)
		-- 状態遷移
		ProcessCommand(myid, msg)
	end

	-- アイドル
	if (m_CurrentState == STATE_IDLE) then
		EventIdle(myid)
		return
	-- 主人追跡
	elseif (m_CurrentState == STATE_FOLLOW) then
		EventFollow(myid)
		return
	-- 敵追跡
	elseif (m_CurrentState == STATE_CHASE) then
		EventChaseEnemy(myid)
		return
	-- 敵殲滅
	elseif (m_CurrentState == STATE_ATTACK) then
		EventAttackEnemy(myid)
		return
	end

	-- デフォルトでアイドル
	m_CurrentState = STATE_IDLE
	TraceAI("AI : STATE_IDLE")

end

