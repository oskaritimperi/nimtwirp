all: haberdasherserver haberdasherclient

haberdasherserver: haberdasherserver.nim service_pb.nim service_twirp.nim
	nim c haberdasherserver.nim

haberdasherclient: haberdasherclient.nim service_pb.nim service_twirp.nim
	nim c haberdasherclient.nim

%_pb.nim %_twirp.nim: %.proto
	../../nimtwirp/nimtwirp_build -I:. --out:. $^
