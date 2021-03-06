-- The API is mostly inspired by the official Spring protocol with some major differences such as:
-- AI is used to denote a game AI, while bot is only used for automated lobby bots
-- TODO: rest

VFS.Include(LIB_LOBBY_DIRNAME .. "observable.lua")
VFS.Include(LIB_LOBBY_DIRNAME .. "utilities.lua")

function Lobby:init()
	self.listeners = {}
	-- don't use these fields directly, they are subject to change
	self:_Clean()
end

function Lobby:_Clean()
	self.users = {}
	self.userCount = 0

	self.friends = {} -- list
	self.isFriend = {} -- map
	self.friendCount = 0
	self.friendRequests = {} -- list
	self.hasFriendRequest = {} -- map
	self.friendRequestCount = 0

	self.channels = {}
	self.channelCount = 0

	self.battles = {}
	self.battleCount = 0
	self.modoptions = {}

	self.userBattleStatus = {}

	self.queues = {}
	self.queueCount = 0

	self.team = nil

	self.latency = 0 -- in ms

	self.loginData = nil
	self.myUserName = nil
	self.myChannels = {}
	self.myBattleID = nil
	self.scriptPassword = nil

	-- reconnection delay in seconds
	self.reconnectionDelay = 5
end

function Lobby:_PreserveData()
	self._oldData = {
		--channels = ShallowCopy(self.channels),
		--battles = ShallowCopy(self.battles),
		loginData = ShallowCopy(self.loginData),
		myUserName = self.myUserName,
		host = self.host,
		port = self.port,
	}
end

local function GenerateScriptTxt(battleID)
	local battle = lobby:GetBattle(battleID)
	local scriptTxt =
[[
[GAME]
{
	HostIP=__IP__;
	HostPort=__PORT__;
	IsHost=0;
	MyPlayerName=__MY_PLAYER_NAME__;
	MyPasswd=__MY_PASSWD__;
}
]]

	scriptTxt = scriptTxt:gsub("__IP__", battle.ip)
						:gsub("__PORT__", battle.port)
						:gsub("__MY_PLAYER_NAME__", lobby:GetMyUserName())
						:gsub("__MY_PASSWD__", lobby:GetScriptPassword())
	return scriptTxt
end

-- TODO: This doesn't belong in the API. Battleroom chat commands are not part of the protocol (yet), and will cause issues with rooms where !start doesn't do anything.
function Lobby:StartBattle()
	self:SayBattle("!start")
	return self
end

-- TODO: Provide clean implementation/specification
function Lobby:SelectMap(mapName)
	self:SayBattle("!map " .. mapName)
end

-------------------------------------------------
-- BEGIN Client commands
-------------------------------------------------

------------------------
-- Connectivity commands
------------------------

function Lobby:Connect(host, port)
	self.host = host
	self.port = port
	return self
end

function Lobby:Register(userName, password, email)
	return self
end

function Lobby:Login(user, password, cpu, localIP, lobbyVersion)
	self.myUserName = user
	self.loginData = { user, password, cpu, localIP, lobbyVersion}
	return self
end

function Lobby:Ping()
	self.pingTimer = Spring.GetTimer()
end

------------------------
-- User commands
------------------------

-- FIXME: Currently uberserver requires to explicitly ask for the friend and friend request lists. This could be removed to simplify the protocol.
function Lobby:FriendList()
	return self
end
function Lobby:FriendRequestList()
	return self
end

function Lobby:FriendRequest(userName)
	return self
end

function Lobby:AcceptFriendRequest(userName)
	local user = self:GetUser(userName)
	if user then
		user.hasFriendRequest = false
	end
	return self
end

function Lobby:DeclineFriendRequest(userName)
	local user = self:GetUser(userName)
	if user then
		user.hasFriendRequest = false
	end
	return self
end

function Lobby:Unfriend(userName)
	return self
end

function Lobby:Ignore(userName)
	return self
end

function Lobby:Unignore(userName)
	return self
end

------------------------
-- Battle commands
------------------------

function Lobby:HostBattle(battleName, password)
	return self
end

function Lobby:JoinBattle(battleID, password, scriptPassword)
	return self
end

function Lobby:LeaveBattle()
	return self
end

function Lobby:SetBattleStatus(status)
	return self
end

function Lobby:AddAi(aiName, allyNumber, allyNumber)
	return self
end

function Lobby:RemoveAi(aiName)
	return self
end

function Lobby:SayBattle(message)
	return self
end

function Lobby:SayBattleEx(message)
	return self
end

function Lobby:ConnectToBattle(useSpringRestart)
	if not self.myBattleID then
		Spring.Echo("Cannot connect to battle.")
		return
	end
	self:_CallListeners("OnBattleAboutToStart")

	Spring.Echo("Game starts!")
	local battle = self:GetBattle(self.myBattleID)
	local springURL = "spring://" .. self:GetMyUserName() .. ":" .. self:GetScriptPassword() .. "@" .. battle.ip .. ":" .. battle.port
	Spring.Echo(springURL)
	if useSpringRestart then
		Spring.Restart(springURL, "")
	else
		Spring.Start(springURL, "")
	end
	--local scriptFileName = "scriptFile.txt"
	--local scriptFile = io.open(scriptFileName, "w")
	--local scriptTxt = GenerateScriptTxt(battleID)
	--Spring.Echo(scriptTxt)
	--scriptFile:write(scriptTxt)
	--scriptFile:close()
	--Spring.Restart(scriptFileName, "")
	--Spring.Restart("", scriptTxt)
end

function Lobby:VoteYes()
	return self
end

function Lobby:VoteNo()
	return self
end

------------------------
-- Channel & private chat commands
------------------------

function Lobby:Join(chanName, key)
	return self
end

function Lobby:Leave(chanName)
	self:_OnLeft(chanName, self.myUserName, "left")
	return self
end

function Lobby:Say(chanName, message)
	return self
end

function Lobby:SayEx(chanName, message)
	return self
end

function Lobby:SayPrivate(userName, message)
	return self
end

-------------------------------------------------
-- END Client commands
-------------------------------------------------

-------------------------------------------------
-- BEGIN Server commands
-------------------------------------------------

------------------------
-- Connectivity commands
------------------------

function Lobby:_OnConnect(protocolVersion, springVersion, udpPort, serverMode)
	if self.status == "disconnected" and self.disconnectTime ~= nil then -- in the process of reconnecting
		self.disconnectTime = nil
		self:Login(unpack(self._oldData.loginData))
	end
	self:_CallListeners("OnConnect", protocolVersion, springVersion, udpPort, serverMode)
end

function Lobby:_OnAccepted()
	if self.status == "connecting" then
		self.status = "connected"
	end
	self:_CallListeners("OnAccepted")
end

function Lobby:_OnDenied(reason)
	self:_CallListeners("OnDenied", reason)
end

-- TODO: rework, should be only one callin
function Lobby:_OnAgreement(line)
	self:_CallListeners("OnAgreement", line)
end

-- TODO: Merge with _OnAgreement into a single callin
function Lobby:_OnAgreementEnd()
	self:_CallListeners("OnAgreementEnd")
end

function Lobby:_OnRegistrationAccepted()
	self:_CallListeners("OnRegistrationAccepted")
end

function Lobby:_OnRegistrationDenied(reason)
	self:_CallListeners("OnRegistrationDenied", reason)
end

function Lobby:_OnLoginInfoEnd()
	self:_CallListeners("OnLoginInfoEnd")
end

function Lobby:_OnPong()
	self.pongTimer = Spring.GetTimer()
	if self.pingTimer then
		self.latency = Spring.DiffTimers(self.pongTimer, self.pingTimer, true)
	else
		Spring.Echo("missing self.pingTimer")
	end
	self:_CallListeners("OnPong")
end

------------------------
-- User commands
------------------------

function Lobby:_OnAddUser(userName, country, cpu, accountID, lobbyVersion, clan)
	self.userCount = self.userCount + 1
	self.users[userName] = {
		userName = userName,
		country = country,
		cpu = cpu,
		accountID = accountID,
		lobbyVersion = lobbyVersion,
		clan = clan,
		isFriend = self.isFriend[userName],
		hasFriendRequest = self.hasFriendRequest[userName],
	}
	self:_CallListeners("OnAddUser", userName, country, cpu, accountID, lobbyVersion, clan)
end

function Lobby:_OnRemoveUser(userName)
	if not self.users[userName] then
		Spring.Log("liblobby", LOG.ERROR, "Tried to remove missing user", userName)
		return
	end
	local userInfo = self.users[userName]
	-- preserve isFriend/hasFriendRequest
	local isFriend, hasFriendRequest = userInfo.isFriend, userInfo.hasFriendRequest
	self.users[userName] = nil
	if isFriend or hasFriendRequest then
		userInfo = self:TryGetUser(userName)
		userInfo.isFriend         = isFriend
		userInfo.hasFriendRequest = hasFriendRequest
	end
	self.userCount = self.userCount - 1
	self:_CallListeners("OnRemoveUser", userName)
end

-- Updates the specified status keys
-- Status keys can be: isAway, isInGame, isModerator, rank, isBot
-- Example: _OnUpdateUserStatus("gajop", {isAway=false, isInGame=true})
function Lobby:_OnUpdateUserStatus(userName, status)
	for k, v in pairs(status) do
		self.users[userName][k] = v
	end
	self:_CallListeners("OnUpdateUserStatus", userName, status)

	if status.isInGame ~= nil then
		self:_OnBattleIngameUpdate(userName, status.isInGame)
		if self.myBattleID and status.isInGame then
			local myBattle = self:GetBattle(self.myBattleID)
			if myBattle and myBattle.founder == userName then
				self:ConnectToBattle(self.useSpringRestart)
			end
		end
	end
end

function Lobby:_OnFriend(userName)
	table.insert(self.friends, userName)
	self.isFriend[userName] = true
	self.friendCount = self.friendCount + 1
	local userInfo = self:TryGetUser(userName)
	userInfo.isFriend = true
	self:_CallListeners("OnFriend", userName)
end

function Lobby:_OnUnfriend(userName)
	for i, v in pairs(self.friends) do
		if v == userName then
			table.remove(self.friends, i)
			break
		end
	end
	self.isFriend[userName] = false
	self.friendCount = self.friendCount - 1
	local userInfo = self:GetUser(userName)
	-- don't need to create offline users in this case
	if userInfo then
		userInfo.isFriend = false
	end
	self:_CallListeners("OnUnfriend", userName)
end

function Lobby:_OnFriendList(friends)
	self.friends = friends
	self.friendCount = #friends
	for _, userName in pairs(self.friends) do
		self.isFriend[userName] = true
		local userInfo = self:TryGetUser(userName)
		userInfo.isFriend = true
	end
	self:_CallListeners("OnFriendList", self:GetFriends())
end

function Lobby:_OnFriendRequest(userName)
	table.insert(self.friendRequests, userName)
	self.hasFriendRequest[userName] = true
	self.friendRequestCount = self.friendRequestCount + 1
	local userInfo = self:TryGetUser(userName)
	userInfo.hasFriendRequest = true
	self:_CallListeners("OnFriendRequest", userName)
end

function Lobby:_OnFriendRequestList(friendRequests)
	self.friendRequests = friendRequests
	self.friendRequestCount = #friendRequests
	for _, userName in pairs(self.friendRequests) do
		self.hasFriendRequest[userName] = true
		local userInfo = self:TryGetUser(userName)
		userInfo.hasFriendRequest = true
	end
	self:_CallListeners("OnFriendRequestList", self:GetFriendRequests())
end

------------------------
-- Battle commands
------------------------

function Lobby:_OnBattleIngameUpdate(userName, isInGame)
	local battleID = self:GetBattleFoundedBy(userName)
	if battleID then
		self.battles[battleID].isRunning = isInGame
		self:_CallListeners("OnBattleIngameUpdate", battleID, isInGame)
	end
end

-- TODO: This function has an awful signature and should be reworked. At least make it use a key/value table.
function Lobby:_OnBattleOpened(battleID, type, natType, founder, ip, port, maxPlayers, passworded, rank, mapHash, other, engineVersion, mapName, title, gameName, spectatorCount)
	self.battles[battleID] = {
		battleID=battleID, type=type, natType=natType, founder=founder, ip=ip, port=port,
		maxPlayers=maxPlayers, passworded=passworded, rank=rank, mapHash=mapHash, spectatorCount = spectatorCount or 0,
		engineName=engineName, engineVersion=engineVersion, mapName=mapName, title=title, gameName=gameName, users={founder},
	}
	self.battleCount = self.battleCount + 1

	self.battles[battleID].isRunning = self.users[founder].isInGame

	self:_CallListeners("OnBattleOpened", battleID, type, natType, founder, ip, port, maxPlayers, passworded, rank, mapHash, engineName, engineVersion, map, title, gameName)
end

function Lobby:_OnBattleClosed(battleID)
	self.battles[battleID] = nil
	self.battleCount = self.battleCount - 1
	self:_CallListeners("OnBattleClosed", battleID)
end

function Lobby:_OnJoinBattle(battleID, hashCode)
	self.myBattleID = battleID
	self.modoptions = {}

	self:_CallListeners("OnJoinBattle", battleID, hashCode)
end

function Lobby:_OnJoinedBattle(battleID, userName, scriptPassword)
	table.insert(self.battles[battleID].users, userName)

	self.users[userName].battleID = battleID
	self:_CallListeners("OnUpdateUserStatus", userName, {battleID = battleID})

	self:_CallListeners("OnJoinedBattle", battleID, userName, scriptPassword)
end

function Lobby:_OnBattleScriptPassword(scriptPassword)
	self.scriptPassword = scriptPassword
	self:_CallListeners("OnBattleScriptPassword", scriptPassword)
end

function Lobby:_OnLeftBattle(battleID, userName)
	if self:GetMyUserName() == userName then
		self.myBattleID = nil
		self.modoptions = {}
	end

	local battleUsers = self.battles[battleID].users
	for i, v in pairs(battleUsers) do
		if v == userName then
			table.remove(battleUsers, i)
			break
		end
	end

	self.users[userName].battleID = nil
	self:_CallListeners("OnUpdateUserStatus", userName, {battleID = false})

	self:_CallListeners("OnLeftBattle", battleID, userName)
end

function Lobby:_OnUpdateBattleInfo(battleID, spectatorCount, locked, mapHash, mapName)
	local battle = self.battles[battleID]
	battle.spectatorCount = spectatorCount or battle.spectatorCount
	battle.locked         = locked         or battle.locked
	battle.mapHash        = mapHash        or battle.mapHash
	battle.mapName        = mapName        or battle.mapName
	self:_CallListeners("OnUpdateBattleInfo", battleID, spectatorCount, locked, mapHash, mapName)
end

-- Updates the specified status keys
-- Status keys can be: isAway, isInGame, isModerator, rank, isBot, aiLib
-- Bots have isBot=true, AIs have aiLib~=nil and humans are the remaining
-- Example: _OnUpdateUserStatus("gajop", {isAway=false, isInGame=true})
function Lobby:_OnUpdateUserBattleStatus(userName, status)
	if not self.userBattleStatus[userName] then
		self.userBattleStatus[userName] = {}
	end

	local userData = self.userBattleStatus[userName]

	-- If userData.allyNumber is present then an update must occur.
	local changedAllyTeam = userData.allyNumber or (status.allyNumber ~= userData.allyNumber)
	local changedSpectator = (status.isSpectator ~= userData.isSpectator)

	userData.allyNumber = status.allyNumber or userData.allyNumber
	userData.teamNumber = status.teamNumber or userData.teamNumber
	if status.isSpectator ~= nil then
		userData.isSpectator = status.isSpectator
	end
	userData.sync       = status.sync  or userData.sync
	userData.aiLib      = status.aiLib or userData.aiLib
	userData.owner      = status.owner or userData.owner

	status.allyNumber   = userData.allyNumber
	status.teamNumber   = userData.teamNumber
	status.isSpectator  = userData.isSpectator
	status.sync         = userData.sync
	status.aiLib        = userData.aiLib
	status.owner        = userData.owner
	self:_CallListeners("OnUpdateUserBattleStatus", userName, status)

	if changedSpectator or changedAllyTeam then
		--Spring.Echo("OnUpdateUserTeamStatus", changedAllyTeam, changedSpectator, "spectator", status.isSpectator, userData.isSpectator, "ally Team", status.allyNumber, userData.allyNumber)
		self:_CallListeners("OnUpdateUserTeamStatus", userName, status.allyNumber, status.isSpectator)
	end
end

-- Also calls the OnUpdateUserBattleStatus
function Lobby:_OnAddAi(battleID, aiName, status)
	self:_OnAddUser(aiName)
	self:_OnJoinedBattle(battleID, aiName)
	status.isSpectator = false
	self:_OnUpdateUserBattleStatus(aiName, status)
	self:_CallListeners("OnAddAi", aiName, status)
end

function Lobby:_OnRemoveAi(battleID, aiName, aiLib, allyNumber, owner)
	-- TODO: maybe needs proper listeners
	self:_OnLeftBattle(battleID, aiName)
end

function Lobby:_OnSaidBattle(userName, message, sayTime)
	self:_CallListeners("OnSaidBattle", userName, message, sayTime)
end

function Lobby:_OnSaidBattleEx(userName, message, sayTime)
	self:_CallListeners("OnSaidBattleEx", userName, message, sayTime)
end

function Lobby:_OnVoteUpdate(message, yesVotes, noVotes, votesNeeded)
	self:_CallListeners("OnVoteUpdate", message, yesVotes, noVotes, votesNeeded)
end

function Lobby:_OnVoteEnd(message, success)
	self:_CallListeners("OnVoteEnd", message, success)
end

function Lobby:_OnVoteResponse(isYesVote)
	self:_CallListeners("OnVoteResponse", isYesVote)
end

function Lobby:_OnSetModOptions(data)
	for key, value in pairs(data) do
		self.modoptions[key] = value
	end
	self:_CallListeners("OnSetModOptions", data)
end

------------------------
-- Channel & private chat commands
------------------------

function Lobby:_OnChannel(chanName, userCount, topic)
	local channel = self:_GetChannel(chanName)
	channel.userCount = userCount
	channel.topic = topic
	self:_CallListeners("OnChannel", chanName, userCount, topic)
end

function Lobby:_OnChannelTopic(chanName, author, changedTime, topic)
	local channel = self:_GetChannel(chanName)
	channel.topic = topic
	self:_CallListeners("OnChannelTopic", chanName, author, changedTime, topic)
end

-- FIXME: This method feels redundant, and could be implemented by allowing the author, changedTime and topic of _OnChannelTopic to be nil
function Lobby:_OnNoChannelTopic(chanName)
	self:_CallListeners("_OnNoChannelTopic", chanName)
end

function Lobby:_OnClients(chanName, users)
	local channel = self:_GetChannel(chanName)

	if channel.users ~= nil then
		for _, user in pairs(users) do
			local found = false
			for _, existingUser in pairs(channel.users) do
				if user == existingUser then
					found = true
					break
				end
			end
			if not found then
				table.insert(channel.users, user)
			end
		end
	else
		channel.users = users
	end
	self:_CallListeners("OnClients", chanName, users)
end

function Lobby:_OnJoined(chanName, userName)
	local channel = self:_GetChannel(chanName)

	-- only add users after CLIENTS was received
	if channel.users ~= nil then
		local isNewUser = true
		for i, v in pairs(channel.users) do
			if v == userName then
				Spring.Echo("Duplicate user added to channel", chanName, userName)
				isNewUser = false
				break
			end
		end
		if isNewUser then
			table.insert(channel.users, userName)
			self:_CallListeners("OnJoined", chanName, userName)
		end
	end
end

function Lobby:_OnJoin(chanName)
	local isNewChannel = true
	for i, v in pairs(self.myChannels) do
		if v == chanName then
			--Spring.Echo("Duplicate uchannel joined", chanName)
			isNewChannel = false
			break
		end
	end
	if isNewChannel then
		table.insert(self.myChannels, chanName)
	end
	self:_CallListeners("OnJoin", chanName)
end

function Lobby:_OnLeft(chanName, userName, reason)
	local channel = self:_GetChannel(chanName)

	if not (channel and channel.users) then
		return
	end

	if userName == self.myUserName then
		for i, v in pairs(self.myChannels) do
			if v == chanName then
				table.remove(self.myChannels, i)
				break
			end
		end
	end
	for i, v in pairs(channel.users) do
		if v == userName then
			table.remove(channel.users, i)
			break
		end
	end
	self:_CallListeners("OnLeft", chanName, userName, reason)
end

function Lobby:_OnSaid(chanName, userName, message, sayTime)
	self:_CallListeners("OnSaid", chanName, userName, message, sayTime)
end

function Lobby:_OnSaidEx(chanName, userName, message, sayTime)
	self:_CallListeners("OnSaidEx", chanName, userName, message, sayTime)
end

function Lobby:_OnSaidPrivate(userName, message, sayTime)
	self:_CallListeners("OnSaidPrivate", userName, message, sayTime)
end

function Lobby:_OnSaidPrivateEx(userName, message, sayTime)
	self:_CallListeners("OnSaidPrivateEx", userName, message, sayTime)
end

function Lobby:_OnSayPrivate(userName, message, sayTime)
	self:_CallListeners("OnSayPrivate", userName, message, sayTime)
end

function Lobby:_OnSayPrivateEx(userName, message, sayTime)
	self:_CallListeners("OnSayPrivateEx", userName, message, sayTime)
end

------------------------
-- Matchmaking commands
------------------------

function Lobby:_OnListQueues(queues, ...)
	self.queueCount = 0
	self.queues = {}
	for _, queue in pairs(queues) do
		self.queues[queue.name] = queue
		self.queueCount = self.queueCount + 1
	end
end

function Lobby:_OnQueueOpened(queue)
	local name = queue.name
	self.queues[name] = queue
	self.queueCount = self.queueCount + 1
end

function Lobby:_OnQueueClosed(queue)
	local name = queue.name
	self.queues[name] = nil
	self.queueCount = self.queueCount - 1
end

------------------------
-- Team commands
------------------------

function Lobby:_OnJoinedTeam(obj)
	local userName = obj.userName
	table.insert(self.team.users, userName)
end

function Lobby:_OnJoinTeam(obj)
	local userNames = obj.userNames
	local leader = obj.leader
	self.team = { users = userNames, leader = leader }
end

function Lobby:_OnLeftTeam(obj)
	local userName = obj.userName
	local reason = obj.reason
	if userName == self.myUserName then
		self.team = nil
	else
		for i, v in pairs(self.team.users) do
			if v == userName then
				table.remove(self.team.users, i)
				break
			end
		end
	end
end

------------------------
-- Misc
------------------------

function Lobby:_OnLaunchRemoteReplay(url, game, map, engine)
	self:_CallListeners("OnLaunchRemoteReplay", url, game, map, engine)
end


-------------------------------------------------
-- END Server commands
-------------------------------------------------

-------------------------------------------------
-- BEGIN Connection handling TODO: This might be better to move into the shared interface
-------------------------------------------------

function Lobby:_OnDisconnected(...)
	self:_CallListeners("OnDisconnected")

	for battleID, battle in pairs(self.battles) do
		for _, useName in pairs(battle.users) do
			self:_OnLeftBattle(battleID, useName)
		end
		self:_OnBattleClosed(battleID)
	end

	for userName,_ in pairs(self.users) do
		self:_OnRemoveUser(userName)
	end

	self:_PreserveData()
	self:_Clean()
	self.disconnectTime = Spring.GetTimer()
end

function Lobby:Reconnect()
	self.lastReconnectionAttempt = Spring.GetTimer()
	self:Connect(self._oldData.host, self._oldData.port)
end

function Lobby:SafeUpdate(...)
	if self.status == "disconnected" and self.disconnectTime ~= nil then
		local currentTime = Spring.GetTimer()
		if self.lastReconnectionAttempt == nil or Spring.DiffTimers(currentTime, self.lastReconnectionAttempt) > self.reconnectionDelay then
			self:Reconnect()
		end
	end
end

-------------------------------------------------
-- END Connection handling TODO: This might be better to move into the shared interface
-------------------------------------------------

-- will also create a channel if it doesn't already exist
function Lobby:_GetChannel(chanName)
	local channel = self.channels[chanName]
	if channel == nil then
		channel = { chanName = chanName }
		self.channels[chanName] = channel
		self.channelCount = self.channelCount + 1
	end
	return channel
end

function Lobby:GetUnusedTeamID()
	local unusedTeamID = 0
	local takenTeamID = {}
	for name, data in pairs(self.userBattleStatus) do
		if data.TeamNumber and not data.isSpectator then
			local teamID = data.teamNumber
			takenTeamID[teamID] = true
			while takenTeamID[unusedTeamID] do
				unusedTeamID = unusedTeamID + 1
			end
		end
	end
	return unusedTeamID
end

-------------------------------------------------
-- BEGIN Data access
-------------------------------------------------

-- users
function Lobby:GetUserCount()
	return self.userCount
end
-- gets the userInfo, or creates a new one with an offline user if it doesn't exist
function Lobby:TryGetUser(userName)
	local userInfo = self:GetUser(userName)
	if not userInfo then
		userInfo = {
			userName = userName,
			isOffline = true
		}
		self.users[userName] = userInfo
	end
	return userInfo
end
function Lobby:GetUser(userName)
	return self.users[userName]
end
function Lobby:GetUserBattleStatus(userName)
	return self.userBattleStatus[userName]
end
-- returns users table (not necessarily an array)
function Lobby:GetUsers()
	return ShallowCopy(self.users)
end

-- friends
function Lobby:GetFriendCount()
	return self.friendCount
end
-- returns friends table (not necessarily an array)
function Lobby:GetFriends()
	return ShallowCopy(self.friends)
end
function Lobby:GetFriendRequestCount()
	return self.friendRequestCount
end
-- returns friends table (not necessarily an array)
function Lobby:GetFriendRequests()
	return ShallowCopy(self.friendRequests)
end

-- battles
function Lobby:GetBattleCount()
	return self.battleCount
end

function Lobby:GetBattle(battleID)
	return self.battles[battleID]
end

function Lobby:GetBattleFoundedBy(userName)
	-- TODO, improve data structures to make this search nice
	for battleID, battleData in pairs(self.battles) do
		if battleData.founder == userName then
			return battleID
		end
	end
	return false
end

-- returns battles table (not necessarily an array)
function Lobby:GetBattles()
	return ShallowCopy(self.battles)
end

-- queues
function Lobby:GetQueueCount()
	return self.queueCount
end
function Lobby:GetQueue(queueID)
	return self.queues[queueID]
end
-- returns queues table (not necessarily an array)
function Lobby:GetQueues()
	return ShallowCopy(self.queues)
end

-- team
function Lobby:GetTeam()
	return self.team
end

-- channels
function Lobby:GetChannelCount()
	return self.channelCount
end
function Lobby:GetChannel(channelName)
	return self.channels[channelName]
end

function Lobby:GetMyChannels()
	return self.myChannels
end
-- returns channels table (not necessarily an array)
function Lobby:GetChannels()
	return ShallowCopy(self.channels)
end

function Lobby:GetLatency()
	return self.latency
end

-- My data
function Lobby:GetScriptPassword()
	return self.scriptPassword or 0
end

-- My user
function Lobby:GetMyAllyNumber()
	if self.userBattleStatus[self.myUserName] then
		return self.userBattleStatus[self.myUserName].allyNumber
	end
end

function Lobby:GetMyTeamNumber()
	if self.userBattleStatus[self.myUserName] then
		return self.userBattleStatus[self.myUserName].teamNumber
	end
end

function Lobby:GetMyTeamColor()
	if self.userBattleStatus[self.myUserName] then
		return self.userBattleStatus[self.myUserName].teamColor
	end
end

function Lobby:GetMyIsSpectator()
	if self.userBattleStatus[self.myUserName] then
		return self.userBattleStatus[self.myUserName].isSpectator
	end
end

function Lobby:GetMySync()
	if self.userBattleStatus[self.myUserName] then
		return self.userBattleStatus[self.myUserName].sync
	end
end

function Lobby:GetMyIsReady()
	if self.userBattleStatus[self.myUserName] then
		return self.userBattleStatus[self.myUserName].isReady
	end
end

function Lobby:GetMySide()
	if self.userBattleStatus[self.myUserName] then
		return self.userBattleStatus[self.myUserName].side
	end
end

function Lobby:GetMyBattleID()
	return self.myBattleID
end

function Lobby:GetMyBattleModoptions()
	return self.modoptions
end

function Lobby:GetMyUserName()
	return self.myUserName
end

function Lobby:GetMyIsAdmin()
	if self.users[self.myUserName] then
		return self.users[self.myUserName].isAdmin
	end
	return false
end

-------------------------------------------------
-- END Data access
-------------------------------------------------
