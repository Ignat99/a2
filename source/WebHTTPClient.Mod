(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE WebHTTPClient; (** AUTHOR "TF"; PURPOSE "HTTP client"; *)

IMPORT
	TFLog, Streams, IP, DNS, TCP, WebHTTP, Modules;

VAR log : TFLog.Log;

CONST Ok* = 0;

PROCEDURE Head*(CONST url : ARRAY OF CHAR; VAR con : TCP.Connection; VAR header: WebHTTP.ResponseHeader; VAR res : LONGINT);
VAR
	host : ARRAY 128 OF CHAR;
	path : ARRAY 256 OF CHAR;
	port : LONGINT;
	fadr : IP.Adr;
	w : Streams.Writer;
	r : Streams.Reader;
BEGIN
	IF WebHTTP.SplitHTTPAdr(url, host, path, port) THEN
		IF path = "" THEN path := "/" END;
		DNS.HostByName(host, fadr, res);
		IF res = DNS.Ok THEN
			IF  con = NIL THEN NEW(con); con.Open(TCP.NilPort, fadr, port, res); END;
			IF res = TCP.Ok THEN
				Streams.OpenWriter(w, con.Send);
				Streams.OpenReader(r, con.Receive);
				WebHTTP.WriteRequestLine(w, 1, 1, WebHTTP.HeadM, path, host); w.Ln(); w.Update();
				WebHTTP.ParseReply(r, header, res, log);
				IF res = WebHTTP.OK THEN res := Ok END;
				con.Close
			ELSE
				log.Enter; log.String("Head could not connect to  : "); log.String(host); log.Exit
			END
		ELSE
			log.Enter; log.String("Host not found : "); log.String(host); log.Exit
		END;
	END;
END Head;

(** The HTTP versions is ignored and set to 1.0; uri and host are ignored and taken from the url parameter *)
PROCEDURE Get*(CONST url : ARRAY OF CHAR; VAR rHeader : WebHTTP.RequestHeader;
								VAR con : TCP.Connection; VAR header: WebHTTP.ResponseHeader; VAR out : Streams.Reader; VAR res : LONGINT);
VAR
	host : ARRAY 128 OF CHAR;
	path : ARRAY 256 OF CHAR;
	port : LONGINT;
	fadr : IP.Adr;
	w : Streams.Writer;
	x : WebHTTP.AdditionalField;
BEGIN
	IF WebHTTP.SplitHTTPAdr(url, host, path, port) THEN
		IF path = "" THEN path := "/" END;
		DNS.HostByName(host, fadr, res);
		IF res = DNS.Ok THEN
			IF  con = NIL THEN NEW(con); con.Open(TCP.NilPort, fadr, port, res); END;
			IF res = TCP.Ok THEN
				Streams.OpenWriter(w, con.Send);
				Streams.OpenReader(out, con.Receive);
				WebHTTP.WriteRequestLine(w, 1, 0, WebHTTP.GetM, path, host);

				IF rHeader.referer # "" THEN w.String("Referer: "); w.String(rHeader.referer); w.Ln() END;
				IF rHeader.useragent # "" THEN w.String("User-Agent: "); w.String(rHeader.useragent); w.Ln() END;
				IF rHeader.accept # "" THEN w.String("Accept: "); w.String(rHeader.accept); w.Ln() END;
				x := rHeader.additionalFields;

				WHILE x # NIL DO
					w.String(x.key);  w.Char(" "); w.String(x.value);w.Ln();
					x := x.next
				END;
				w.Ln(); w.Update();

				WebHTTP.ParseReply(out, header, res, log);

				WebHTTP.LogResponseHeader(log, header);

				IF res = WebHTTP.OK THEN res := Ok END;
			ELSE
				log.Enter; log.String("Get could not connect to  : "); log.String(host); log.Exit
			END
		ELSE
			log.Enter; log.String("Host not found : "); log.String(host); log.Exit
		END;
	END
END Get;

PROCEDURE CleanUp;
BEGIN
	log.Close
END CleanUp;

BEGIN
	NEW(log, "HTTP Client");
	log.SetLogToOut(FALSE);
	Modules.InstallTermHandler(CleanUp)
END WebHTTPClient.
