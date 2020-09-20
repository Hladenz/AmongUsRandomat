local EVENT = {}

EVENT.id = "AmongUs"
--EVENT.Time = 120

util.AddNetworkString("AmongUsEventBegin")
util.AddNetworkString("AmongUsEventEnd")
util.AddNetworkString("AmongUsPlayerVoted")

CreateConVar("randomat_amongus_timer", 45, {FCVAR_NOTIFY, FCVAR_ARCHIVE}, "Length of the vote")
CreateConVar("randomat_amongus_totalpct", 50, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Percent of total player votes required for a vote to pass, set to 0 to disable")
CreateConVar("randomat_amongus_freeze", false, {FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Should Players be frozen while voting")

local events = {}
events["AmongUs"] = {}
events["AmongUs"].name = "AmongUs"

local eventnames = {}
table.insert(eventnames, "AmongUs")

EVENT.Title = table.Random(eventnames)

local canttalk = true
function EVENT:Begin()
	for k, v in pairs(player.GetAll()) do
		v:ChatPrint("Randomat: AmongUs" )
	end
	local SetMDL = FindMetaTable("Entity").SetModel

	for i, ply in pairs(self:GetAlivePlayers(true)) do
		SetMDL( ply, "models/kaesar/amongus/amongus.mdl" )
	end

	timer.Create("RandomatNoSoundDelay", 1, 1, function()
		hook.Add("Think", "NoSound", function()
			if canttalk then
				for k, v in pairs(player.GetAll()) do
					v:ConCommand("soundfade 100 1")
				end
			end
		end)
	end)
	
	hook.Add("TTTBodyFound", "AmongUsEventBegin", function()
		net.Start("AmongUsEventBegin")
		net.Broadcast()
		local AmongUstimer = GetConVar("randomat_amongus_timer"):GetInt()
		
		playervotes = {}
		votableplayers = {}
		playersvoted = {}
		aliveplys = {}
		local skipkill = 0
		local slainply = 0
		
		for k, v in pairs(player.GetAll()) do
			if not (v:Alive() and v:IsSpec()) then
				votableplayers[k] = v
				playervotes[k] = 0
			end
		end

		if GetConVar("randomat_amongus_freeze"):GetBool() then
			for i, ply in pairs(self:GetAlivePlayers(true)) do
				ply:Freeze( true )
			end
		end

		local repeater = 0
		
		timer.Create("votekilltimerAmongUs", 1, 0, function()	
			repeater = repeater + 1
			if AmongUstimer > 19 and repeater == AmongUstimer - 10 then
				self:SmallNotify("10 seconds left on voting!")
			elseif repeater == AmongUstimer then
				repeater = 0
				local votenumber = 0
				for k, v in pairs(playervotes) do -- Tally up votes
					votenumber = votenumber + v
				end
				for k, v in pairs(self:GetAlivePlayers(true)) do
					table.insert(aliveplys, v)
				end
			
				if votenumber >= #aliveplys*(GetConVar("randomat_amongus_totalpct"):GetInt()/100) and votenumber ~= 0 then --If at least 1 person voted, and votes exceed cap determine who gets killed
					local maxv = 0
					local maxk = {}

					for k, v in pairs(playervotes) do
						if v > maxv then
							maxv = v
							maxk[1] = k
						end
					end

					for k, v in pairs(playervotes) do
						if v == maxv and k ~= maxk[1] then
							table.insert(maxk, k)
						end
					end
					
					self:SmallNotify("The vote was a tie. Everyone stays alive. For now.")
					skipkill = 1

					if skipkill == 0 then
						if slainply:GetRole() == ROLE_JESTER then
							local jesterrepeater = 0
							for voter, tgt in RandomPairs(playersvoted) do
								if jesterrepeater == 0 and voter:GetRole() ~= ROLE_JESTER and tgt == slainply then
									jesterrepeater = 1
									voter:Kill()
									self:SmallNotify(voter:Nick().." was dumb enough to vote for the Jester!")
								end
							end
						else
							slainply:Kill()
							self:SmallNotify(slainply:Nick() .. " was voted for.")
						end
					else
						skipkill = 0
					end
				elseif votenumber == 0 then --If nobody votes
					self:SmallNotify("Nobody was voted for. Everyone stays alive. For now.")
				else
					self:SmallNotify("Not enough players voted. Everyone stays alive. For now.")
				end
				
				ClearTable(playersvoted)
				ClearTable(aliveplys)

				net.Start("AmongUsEventEnd")
				net.Broadcast()
				canttalk = true

				if GetConVar("randomat_amongus_freeze"):GetBool() then
					for i, ply in pairs(self:GetAlivePlayers(true)) do
						ply:Freeze( false )
					end
				end

				for k, v in pairs(playervotes) do
					playervotes[k] = 0
				end
				timer.Stop("votekilltimerAmongUs")
			end	
		end)
	
	end)

	timer.Create("ImposterKnife", 45, 0, function()
		for i, ply in pairs(self:GetAlivePlayers(true)) do
			if table.Count(ply:GetWeapons()) ~= 1 or (table.Count(ply:GetWeapons()) == 1 and ply:GetActiveWeapon():GetClass() ~= "weapon_ttt_knife") then
				if ply:GetRole() == ROLE_TRAITOR then
					ply:Give("weapon_ttt_knife")
				end
			end
		end
	end)

	timer.Create("ImposterRemoveWep", 1, 0, function()
		for i, ply in pairs(self:GetAlivePlayers(true)) do
			if table.Count(ply:GetWeapons()) ~= 1 or (table.Count(ply:GetWeapons()) == 1 and ply:GetActiveWeapon():GetClass() ~= "weapon_ttt_knife") then
				ply:StripWeapons()
			end
		end
	end)

end

net.Receive("AmongUsPlayerVoted", function(ln, ply)
	local voterepeatblock = 0
	local votee = net.ReadString()
	local num

	for k, v in pairs(playersvoted) do
		if k == ply then voterepeatblock = 1 end
		ply:PrintMessage(HUD_PRINTTALK, "you have already voted.")
	end

	for k, v in pairs(votableplayers) do
		if v:Nick() == votee and voterepeatblock == 0 then --find which player was voted for
			playersvoted[ply] = v --insert player and target into table

			for ka, va in pairs(player.GetAll()) do
				va:PrintMessage(HUD_PRINTTALK, ply:Nick().." has voted to kill "..votee) --tell everyone who they voted for
			end

			playervotes[k] = playervotes[k] + 1
			num = playervotes[k]
		end
	end

	net.Start("AmongUsPlayerVoted")
		net.WriteString(votee)
		net.WriteInt(num, 32)
	net.Broadcast()
end)

function EVENT:End()
	hook.Remove("Think", "NoSound")
	hook.Remove("TTTBodyFound", "AmongUsEventBegin")
	
	timer.Remove("votekilltimerAmongUs")
	timer.Remove("RandomatNoSoundDelay")
	timer.Remove("ImposterKnife")
	timer.Remove("ImposterRemoveWep")


	net.Start("AmongUsEventEnd")
	net.Broadcast()
end
Randomat:register(EVENT)