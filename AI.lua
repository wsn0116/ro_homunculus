
require "./AI/Const.lua"
require "./AI/Util.lua"

-- ��Ԓ萔
STATE_IDLE		= 0
STATE_FOLLOW	= 1
STATE_CHASE		= 2
STATE_ATTACK	= 3

-----------------------------------------------------------------------------
-- �ݒ�
-----------------------------------------------------------------------------

-- ��l�̒ǐՂ��J�n���鋗���i���}�X�j
DISTANCE_FOLLOW_OWNER_NORMAL = 5
DISTANCE_FOLLOW_OWNER_ATTACK = 8

-- �^�[�Q�b�g�Ƃ���G�Ƃ̋����i��l���炎�}�X�j
DISTANCE_TARGET_MOB = 5

-- �X�L�������̂��߂̑O�� SP �c�ʁi�����j
USE_SKILL_PERCENTAGE = 35

-- �U���X�L���i�J�v���X�j
USE_ATTACK_SKILL_ID = 8013
USE_ATTACK_SKILL_LV = 5

-- �񕜃X�L���i�J�I�e�B�b�N�x�l�f�B�N�V�����j
USE_SUPPORT_SKILL_ID = 8014
USE_SUPPORT_SKILL_LV = 4

-- �J�v���X
SKILL_CAPRICE             = 8013
-- �J�I�e�B�b�N�x�l�f�B�N�V����
SKILL_CHAOTIC_VENEDICTION = 8014
-- �`�F���W�C���X�g���N�V����
SKILL_CHANGE_INSTRUCTION  = 8015
-- �o�C�I�G�N�X�v���[�W����
SKILL_BIO_EXPLOSION       = 8016

-- ��U�敪�itrue : �A�N�e�B�u, false : �p�b�V�u�j
INTERSECT = false

-----------------------------------------------------------------------------
-- �ϐ�������
-----------------------------------------------------------------------------

-- ���݂̏��
m_CurrentState = STATE_IDLE

-- ���݂̈ړ���
m_DestX = 0
m_DestY = 0

-- ���݂̎g�p�X�L��
m_SkillId = 0
m_SkillLv = 0

-- ���݂̓G
m_EnemyId = 0

-- ���O�̓G
m_PreviousEnemyId = 0

-- �\��R�}���h�p���X�g�I�u�W�F�N�g����
m_ResCmdList = List.new()

-----------------------------------------------------------------------------
-- ���Ԃ�[����
-----------------------------------------------------------------------------

-- ��l�ǐ�
function FollowOwner(myid)

	local dist

	-- 臒l���f
	if (m_CurrentState == STATE_CHASE or m_CurrentState == STATE_ATTACK) then
		dist = DISTANCE_FOLLOW_OWNER_ATTACK
	else
		dist = DISTANCE_FOLLOW_OWNER_NORMAL
	end

	-- 臒l��藣��Ă�����ǐ�
	local owner_id = GetV(V_OWNER, myid)
	if (GetDistanceFromOwner(myid) > dist) then
		-- ��l���ړ����Ă���
		if (GetV(V_MOTION, owner_id) == MOTION_MOVE) then
			-- �C�x���g�������̎�l�ʒu�ֈړ�
			local owner_x, owner_y = GetV(V_POSITION, owner_id)
			-- MoveToOwner ���ƈړ����s���R�Ȃ̂� Move ���g��
			Move(myid, owner_x, owner_y)
		else
			-- ��l�̉��ւ܂�������
			MoveToOwner(myid)
		end

		TraceAI("FollowOwner : " .. m_CurrentState .. " -> STATE_FOLLOW")
		m_CurrentState = STATE_FOLLOW
		return true
	else
		return false
	end

end

-- �G�͂��邩
function HasEnemy()

	if (m_EnemyId == 0) then
		TraceAI("EventChaseEnemy : " .. m_CurrentState .. " -> STATE_IDLE")
		m_CurrentState = STATE_IDLE
		return false
	else
		return true
	end

end

-- �G�ƔF�����A�ǐՂ��J�n����
function RecognizeEnemy(v, reason)

	-- �G���Z�b�g
	m_EnemyId = v

	-- �O��̓G���N���A
	m_PreviousEnemyId = 0

	-- �ǐ�
	TraceAI("RecognizeEnemy : " .. m_CurrentState .. " -> STATE_CHASE (" .. reason .. ")")
	m_CurrentState = STATE_CHASE

end

-- ���G����
function SearchEnemy(myid)

	local i = 1
	local enemies = {}
	local actors = GetActors()

	-- �܂��G������z��Ɋi�[
	for u, v in ipairs(actors) do
		-- ��l�Ǝ����ȊO
		if (v ~= GetV(V_OWNER, myid) and v ~= myid) then
			-- �����X�^�[���I
			if (IsMonster(v) == 1)	then
				-- �O��ǐՂ���߂��G�ł͂Ȃ����i�����G���x�ǐՂ��Ȃ��j
				if (m_PreviousEnemyId ~= v) then
					enemies[i] = v
					i = i + 1
				end
			end
		end
	end

	-- ��l���^�[�Q�b�g�Ƃ��Ă���G�͂��邩
	for u, v in ipairs(enemies) do
		if (GetV(V_TARGET, v) == GetV(V_OWNER, myid)) then
			-- �G�ƔF�肵�ǐ�
			RecognizeEnemy(v, "Target owner")
			return
		end
	end

	--  �������^�[�Q�b�g�Ƃ��Ă���G�͂��邩
	for u, v in ipairs(enemies) do
		-- �������U���ڕW�Ƃ��Ă��邩
		if (GetV(V_TARGET, v) == myid) then
			-- �G�ƔF�肵�ǐ�
			RecognizeEnemy(v, "Target me")
			return
		end
	end

	-- ��l�u���v�^�[�Q�b�g�Ƃ��Ă���G�͂��邩
	for u, v in ipairs(enemies) do
		if (GetV(V_TARGET, GetV(V_OWNER, myid)) == v) then
			-- �G�ƔF�肵�ǐ�
			RecognizeEnemy(v, "Owner is attacking")
			return
		end
	end

	-- �ق��ɓG�͂��邩�i�A�N�e�B�u�ݒ莞�̂݁j
	if (INTERSECT == true) then
		for u, v in ipairs(enemies) do
			-- ���̌����������X�^�[�͎�l���� DISTANCE_TARGET_MOB �}�X�ȓ���
			if (GetDistanceFromOwner(myid) <= DISTANCE_TARGET_MOB) then
				-- �O��ǐՂ���߂��G�ł͂Ȃ����i�����G���x�ǐՂ��Ȃ��j
				if (m_PreviousEnemyId ~= v) then
					-- �G�ƔF�肵�ǐ�
					RecognizeEnemy(v, "Near me")
					return
				end
			end

			-- �e���g���[�O�Ȃ̂Ŗ���
			m_EnemyId = 0
		end
	end

	-- ���͂ɓG�����炸�A������ SP ���\�������āA���� HP �������Ă�����񕜂���
	local cur_hp_per = GetV(V_HP, myid) / GetV(V_MAXHP, myid) * 100
	local cur_sp_per = GetV(V_SP, myid) / GetV(V_MAXSP, myid) * 100
	local judge_per = math.random(100)
	if (cur_hp_per < 100) and (cur_sp_per > USE_SKILL_PERCENTAGE) then
		if (cur_sp_per > judge_per) then
			SkillObject(myid, USE_SUPPORT_SKILL_LV, USE_SUPPORT_SKILL_ID, myid)
		end
	end

	-- �G�����Ȃ�������A�C�h����Ԃֈڍs����
	m_CurrentState = STATE_IDLE
	TraceAI("EventIdle : STATE_IDLE -> STATE_IDLE")

end

-----------------------------------------------------------------------------
-- ��Ԗ�����
-----------------------------------------------------------------------------

-- �A�C�h��
function EventIdle(myid)

	-- �߂��Ɏ�l�����Ȃ�������ǂ�������
	if (FollowOwner(myid, m_CurrentState) == true) then
		return
	end

	-- �\��R�}���h������Ύ��s����
	local msg = List.popleft(m_ResCmdList)
	if (msg ~= nil) then
		-- �\��R�}���h����
		ProcessCommand(myid, msg)
		return 
	end

	-- ���G����
	SearchEnemy(myid)

end

-- ��l�ǐ�
function EventFollow(myid)

	-- �߂��Ɏ�l�����Ȃ�������ǂ�������
	if (FollowOwner(myid) == true) then
		return
	else
		m_CurrentState = STATE_IDLE
		TraceAI("EventFollow : STATE_FOLLOW -> STATE_IDLE")
	end

end

-- �G�ǐ�
function EventChaseEnemy(myid)

	-- �߂��Ɏ�l�����Ȃ��������l��ǂ�������i�[�ǂ��h�~�j
	if (FollowOwner(myid) == true) then
		-- ���߂��G���o���Ă���
		m_PreviousEnemyId = m_EnemyId
		return
	end

	-- �G�͂��邩
	if (HasEnemy() == false) then
		return
	end

	-- �G�͎��񂾂�
	if (GetV(V_MOTION, m_EnemyId) == MOTION_DEAD) then
		m_EnemyId = 0
		m_CurrentState = STATE_IDLE
		TraceAI("EventChaseEnemy : STATE_CHASE -> STATE_IDLE")
		return
	end

	-- �G�Ƃ̋���
	local dist = GetDistance2(myid, m_EnemyId)
	-- �˒����o
	local attack_range = GetV(V_ATTACKRANGE, myid)

	-- �U�����f
	if (attack_range >= dist) then
		-- �˒����Ȃ�U��
		m_CurrentState = STATE_ATTACK
		TraceAI("EventChaseEnemy : STATE_CHASE -> STATE_ATTACK")
	else
		-- �˒��O, �G�ɓ��B���Ă��邩
		local enemy_x, enemy_y = GetV(V_POSITION, m_EnemyId)
		-- �G�ɒǂ����Ă��Ȃ��Ȃ�ǐՑ��s
		if (m_DestX ~= enemy_x or m_DestY ~= enemy_y) then
			m_DestX = enemy_x
			m_DestY = enemy_y
			Move(myid, enemy_x, enemy_y)
			m_CurrentState = STATE_CHASE
			TraceAI("EventChaseEnemy : STATE_CHASE -> STATE_CHASE")

		-- �s����ɓG�����Ȃ��Ƃ��͍č��G����
		else
			m_EnemyId = 0
			m_DestX = 0
			m_DestY = 0
			m_CurrentState = STATE_IDLE
			TraceAI("EventChaseEnemy : STATE_CHASE -> STATE_IDLE")
		end
	end

end

-- �G�r��
function EventAttackEnemy(myid)

	-- �߂��Ɏ�l�����Ȃ��������l��ǂ�������
	if (FollowOwner(myid) == true) then
		return
	end

	-- �G�͂��邩
	if (HasEnemy() == false) then
		return
	end

	-- �G�͎���
	if (GetV(V_MOTION, m_EnemyId) == MOTION_DEAD) then
		m_EnemyId = 0
		m_CurrentState = STATE_IDLE
		TraceAI("EventAttackEnemy : STATE_ATTACK -> STATE_IDLE")
		return
	end

	-- �G�Ƃ̋���
	local my_x, my_y = GetV (V_POSITION, myid)
	local enemy_x, enemy_y = GetV(V_POSITION, m_EnemyId)
	local dist = GetDistance (my_x, my_y, enemy_x, enemy_y)
	-- �˒����o
	local attack_range = GetV(V_ATTACKRANGE, myid)

	-- �˒����Ȃ�U������
	if (attack_range >= dist) then
		-- �R�}���h�ɂ��w�������邩
		if (m_SkillId == 0 and m_SkillLv == 0) then
			-- �U�����@����i�c�� SP ���o�j
			local cur_sp_per = GetV(V_SP, myid) / GetV(V_MAXSP, myid) * 100
			if (cur_sp_per < USE_SKILL_PERCENTAGE) then
				-- SP ���c�菭�Ȃ��Ƃ��͕����U������
				Attack (myid, m_EnemyId)
			else
				local judge_per = math.random(100)
				TraceAI("Skill Judge : " .. cur_sp_per .. " <= " .. judge_per)
				-- SP �� USE_SKILL_PERCENTAGE % �ȏ゠��Ƃ��̓X�L���g�p����
				if (cur_sp_per <= judge_per) then
					-- �����U��
					Attack (myid, m_EnemyId)
				else
					-- �X�L���U��
					SkillObject(myid, USE_ATTACK_SKILL_LV, USE_ATTACK_SKILL_ID, m_EnemyId)
				end
			end
		else
			-- �R�}���h�ɂ��X�L���g�p
			SkillObject(myid, m_SkillLv, m_SkillId, m_EnemyId)
			TraceAI("EventAttackEnemy : Used skill by command")
		end

		-- �g�p�X�L���\��������Z�b�g
		m_SkillLv = 0
		m_SkillId = 0

		m_CurrentState = STATE_ATTACK
		TraceAI("EventAttackEnemy : STATE_ATTACK -> STATE_ATTACK")
	else
		-- �˒��O�Ȃ炠����߂�
		m_EnemyId = 0
		m_CurrentState = STATE_IDLE
		TraceAI("EventAttackEnemy : STATE_ATTACK -> STATE_IDLE")
	end

end

-----------------------------------------------------------------------------
-- ���̓R�}���h����
-----------------------------------------------------------------------------

-- �ҋ@
function CmdIdle(myid)
	m_CurrentState = STATE_IDLE
	TraceAI("CmdIdle : STATE_IDLE")
end

-- �ړ�
function CmdMove(myid, x, y)
	-- ����ꂽ�ʂ�Ɉړ�����
	Move(myid, x, y)
end

-- �U��
function CmdAttack(myid, target_id)
	-- �^�[�Q�b�g���Z�b�g
	m_EnemyId = target_id

	-- �܂��ڕW��ǐՂ���
	m_CurrentState = STATE_CHASE
	TraceAI("CmdAttack : STATE_CHASE")
end

-- �X�L���U��
function CmdSkillAttack(myid, skill_lv, skill_id, target_id)
	-- �^�[�Q�b�g���Z�b�g
	m_EnemyId = target_id

	-- �g�p�X�L���\������Z�b�g
	m_SkillLv = skill_lv
	m_SkillId = skill_id

	-- �܂��ڕW��ǐՂ���
	m_CurrentState = STATE_CHASE
	TraceAI("CmdAttack : STATE_CHASE")
end

-----------------------------------------------------------------------------
-- ��ԑJ�ڏ���
-----------------------------------------------------------------------------
function ProcessCommand(myid, msg)

	-- �ҋ@
	if (msg[1] == HOLD_CMD) then
		CmdIdle(myid)
	end

	-- �ړ�
	if (msg[1] == MOVE_CMD) then
		CmdMove(myid, msg[2], msg[3])
	end

	-- �U��
	if (msg[1] == ATTACK_OBJECT_CMD) then
		CmdAttack(myid, msg[2])
	end

	-- �X�L���g�p
	if (msg[1] == SKILL_OBJECT_CMD) then
		CmdSkillAttack(myid, msg[2], msg[3], msg[4])
	end

end

-----------------------------------------------------------------------------
-- AI ���C��
-----------------------------------------------------------------------------
function AI(myid)

	-- �ʏ�R�}���h
	local msg = GetMsg (myid)
	-- �\��R�}���h
	local rmsg = GetResMsg (myid)

	-- �R�}���h����
	if msg[1] == NONE_CMD then
		-- �ʏ�R�}���h���Ȃ��Ƃ��́A�\��R�}���h����������
		if rmsg[1] ~= NONE_CMD then
			if List.size(m_ResCmdList) < 10 then
				-- �\��R�}���h�ۑ�
				List.pushright(m_ResCmdList, rmsg)
			end
		end
	else
		-- �V�����R�}���h�����͂��ꂽ��A�\��R�}���h�͍폜����
		List.clear (m_ResCmdList)
		-- ��ԑJ��
		ProcessCommand(myid, msg)
	end

	-- �A�C�h��
	if (m_CurrentState == STATE_IDLE) then
		EventIdle(myid)
		return
	-- ��l�ǐ�
	elseif (m_CurrentState == STATE_FOLLOW) then
		EventFollow(myid)
		return
	-- �G�ǐ�
	elseif (m_CurrentState == STATE_CHASE) then
		EventChaseEnemy(myid)
		return
	-- �G�r��
	elseif (m_CurrentState == STATE_ATTACK) then
		EventAttackEnemy(myid)
		return
	end

	-- �f�t�H���g�ŃA�C�h��
	m_CurrentState = STATE_IDLE
	TraceAI("AI : STATE_IDLE")

end

