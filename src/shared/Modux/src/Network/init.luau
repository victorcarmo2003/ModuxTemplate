--!strict
-- Registro de pacotes de rede (lync). Diferente do resto de src/shared/Modux,
-- este arquivo é específico de projeto -- é aqui que você declara os pacotes
-- que o seu jogo precisa. Os pacotes abaixo são só os usados pelos módulos
-- essenciais deste template (ProfileService, VitalService/VitalComponent,
-- AnimateController). Adicione os seus conforme for criando features novas,
-- e mantenha CoreTypes.Network em sincronia.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Modux.Types)
local lync = require(script.lync)

type Packet<T> = lync.Packet<T>
type DataTemplate = Types.DataTemplate
type DataTemplateKey = Types.DataTemplateKey
type DataKeyPayload = Types.DataKeyPayload
type KeyedPacket<K, V> = Packet<{ key: K, value: V }> & {
	sendKey: (self: KeyedPacket<K, V>, key: K, value: V, target: any?) -> (),
	onKey: (
		self: KeyedPacket<K, V>,
		fn: (key: K, value: V, sender: Player?, timestamp: number?) -> ()
	) -> lync.Connection,
}

local Network = {}
setmetatable(Network, { __index = lync })
Network.__index = Network

function Network.keyPacket(name: string, valueCodecs: { [string]: any }, options: any?): any
	local variants = {}
	for key, codec in valueCodecs do
		variants[key] = Network.struct({ value = codec })
	end

	local packet = Network.packet(name, Network.tagged("key", variants), options)
	local keyedPacket = {}

	keyedPacket.send = function(_self, data, target)
		packet:send(data, target)
	end

	keyedPacket.on = function(_self, fn)
		return packet:on(fn)
	end

	keyedPacket.once = function(_self, fn)
		return packet:once(fn)
	end

	keyedPacket.wait = function(_self)
		return packet:wait()
	end

	keyedPacket.name = function(_self)
		return packet:name()
	end

	keyedPacket.stats = function(_self)
		return packet:stats()
	end

	keyedPacket.sendKey = function(_self, key, value, target)
		packet:send({
			key = key,
			value = value,
		}, target)
	end

	keyedPacket.onKey = function(_self, fn)
		return packet:on(function(payload, sender, timestamp)
			fn(payload.key, payload.value, sender, timestamp)
		end)
	end

	return table.freeze(keyedPacket)
end

Network.Packages = {
	-- ProfileService (src/server/Services/ProfileService) — replicação do Profile inteiro
	-- e por-key (ver src/shared/Templates/Profile.luau para o schema).
	Data = Network.packet(
		"Data",
		Network.struct({
			Gems = Network.int(0, 4294967295),
			FirstLogin = Network.bool,
			MusicVolume = Network.int(0, 100),
			SoundVolume = Network.int(0, 100),
			MusicEnabled = Network.bool,
			SoundEnabled = Network.bool,
		})
	) :: Packet<DataTemplate>,

	DataKey = Network.keyPacket("DataKey", {
		Gems = Network.int(0, 4294967295),
		FirstLogin = Network.bool,
		MusicVolume = Network.int(0, 100),
		SoundVolume = Network.int(0, 100),
		MusicEnabled = Network.bool,
		SoundEnabled = Network.bool,
	}) :: KeyedPacket<DataTemplateKey, any> & Packet<DataKeyPayload>,

	-- VitalService / VitalComponent (src/server/Services/Player, src/server/Components/Player)
	VitalKey = Network.keyPacket("VitalKey", {
		Armor = Network.int(0, 100),
		Health = Network.int(0, 100),
		Stamina = Network.int(0, 100),
	}),

	GetVitals = Network.query(
		"GetVitals",
		Network.nothing,
		Network.struct({
			Armor = Network.int(0, 100),
			Health = Network.int(0, 100),
			Stamina = Network.int(0, 100),
		})
	),

	-- AnimateController (src/client/Controllers/Player)
	AnimationState = Network.packet(
		"AnimationState",
		Network.struct({
			State = Network.enum("Idle", "Walk", "Sprint", "Crouch", "Jump", "Fall", "Land", "Emote"),
			EmoteId = Network.int(0, 15),
		}),
		{ rateLimit = { maxPerSecond = 10 } }
	),
}

Network.flushRate(60)
Network.start()

return Network
