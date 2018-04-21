all: server client

server: server.nim fooservice_pb.nim fooservice_twirp.nim barservice_pb.nim barservice_twirp.nim
	nim c server.nim

client: client.nim fooservice_pb.nim fooservice_twirp.nim barservice_pb.nim barservice_twirp.nim
	nim c client.nim

%_pb.nim %_twirp.nim: %.proto
	../../nimtwirp/nimtwirp_build -I:. --out:. $^
