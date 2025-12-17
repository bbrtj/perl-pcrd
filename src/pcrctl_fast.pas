program pcrctl_fast;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils, Sockets, BaseUnix, Classes, RegExpr;

{ Need to be kept in sync with PCRD::Protocol }
const
	CSeparator = #9;
	CSuccess = 'ok';
	CError = 'nok';
	CHandshake = '+';
	CTerminator = #10'---'#10;
	CTrue = 'true';
	CFalse = 'false';

type
	TProgramArgs = record
		Module: String;
		Feature: String;
		Value: String;
	end;

	ESocket = class(Exception)
	private
		FSocketError: LongInt;
		function StringifyError(): String;
	public
		constructor Create(const Ex: String);
		function ToString(): String; override;
	end;

{ implementation }

function ESocket.StringifyError(): String;
begin
	case FSocketError of
		EsockADDRINUSE: result := 'Socket address is already in use';
		EsockEACCESS: result := 'Access forbidden';
		EsockEBADF: result := 'Bad file descriptor';
		EsockEFAULT: result := 'An error occurred';
		EsockEINTR: result := 'Operation interrupted';
		EsockEINVAL: result := 'Invalid value specified';
		EsockEMFILE: result := 'Error code ?';
		EsockEMSGSIZE: result := 'Wrong message size error';
		EsockENOBUFS: result := 'No buffer space available';
		EsockENOTCONN: result := 'Not connected';
		EsockENOTSOCK: result := 'File descriptor is not a socket';
		EsockEPROTONOSUPPORT: result := 'Protocol not supported';
		EsockEWOULDBLOCK: result := 'Operation would block';
		otherwise result := 'Unknown error';
	end;
end;

constructor ESocket.Create(const Ex: String);
begin
	inherited Create(Ex);
	FSocketError := SocketError;
end;

function ESocket.ToString(): String;
begin
	result := inherited ToString + ', ' + self.StringifyError;
end;

{ implementation end }

function ReadArguments(): TProgramArgs;
var
	I: Int32;

	function HasNextParam(): Boolean;
	begin
		result := I < ParamCount();
	end;

	function NextParam(): String;
	begin
		I += 1;

		if I > ParamCount() then
			raise Exception.Create('Invalid command line parameters');

		result := ParamStr(I);
	end;

begin
	I := 0;

	result.Module := NextParam();
	result.Feature := NextParam();

	if HasNextParam() then
		result.Value := NextParam();
end;

function GetSocketPath(): String;
var
	LPcrdPath: String;
	LConfig: TStringList;
	LRegex: TRegExpr;
	I: Integer;
begin
	LPcrdPath := GetEnvironmentVariable('PCRD_PATH');
	if LPcrdPath = '' then
		LPcrdPath := '/etc/pcrd';

	result := '/var/run/pcrd.sock';

	LConfig := TStringList.Create;
	LRegex := TRegExpr.Create;
	try
		LConfig.LoadFromFile(LPcrdPath + '/pcrd.conf');
		LRegex.Expression := '^ \s* ([\w.]+) \s*=\s* (.+?) \s* $';
		LRegex.ModifierX := True;
		LRegex.Compile;
		for I := 0 to LConfig.Count - 1 do begin
			if not LRegex.Exec(LConfig[I]) then continue;
			if LRegex.Match[1] <> 'socket.file' then continue;
			result := LRegex.Match[2];
			break;
		end;
	finally
		LConfig.Free;
		LRegex.Free;
	end;
end;

function SocketConnect(Address: String): TSocket;
var
	LAddr: TUnixSockAddr;
begin
	result := fpSocket(AF_UNIX, SOCK_STREAM, 0);
	LAddr.family := AF_UNIX;
	StrPCopy(@LAddr.path, Address);

	if result = -1 then
		raise ESocket.Create('Error creating socket');

	if fpConnect(result, @LAddr, SizeOf(LAddr)) = -1 then
		raise ESocket.Create('Error connecting to ' + Address);
end;

procedure SendQuery(Socket: TSocket; Args: TProgramArgs);
	procedure SocketSend(Data: String);
	begin
		Data += CTerminator;
		if Length(Data) <> fpSend(Socket, @Data[1], Length(Data), 0) then
			raise ESocket.Create('Error sending');
	end;

var
	LData: String;
begin
	if Length(Args.Value) > 0 then
		LData := String.Join(CSeparator, [Args.Module, Args.Feature, 'w', Args.Value])
	else
		LData := String.Join(CSeparator, [Args.Module, Args.Feature, 'r']);

	SocketSend(CHandshake + 'query');
	SocketSend(LData);
end;

function CheckResponse(Socket: TSocket): Boolean;
var
	LBuffer: Array[0 .. 1000] of Char;
	LData: String;
	LRead: Int64;
begin
	LRead := fpRecv(Socket, @LBuffer[0], High(LBuffer), 4);
	result := False;
	if LRead = -1 then
		raise ESocket.Create('Error receiving');

	LData := String(PChar(LBuffer));
	result := Pos(CSuccess, LData) = 1;
end;

var
	LSock: TSocket;
	LRes: Boolean;
begin
	LSock := SocketConnect(GetSocketPath);
	LRes := False;

	try try
		SendQuery(LSock, ReadArguments);
		LRes := CheckResponse(LSock);
	except
		on Ex: Exception do begin
			Writeln(StdErr, Ex.ToString);
		end;
	end;
	finally
		fpClose(LSock);
	end;

	if LRes then
		Halt(0)
	else
		Halt(1);
end.

