unit o_Cli;

{$MODE Delphi}{$H+}

interface

uses
  SysUtils, Classes;

type
  TCliResult = record
    FileName: string;
    Arguments: string;
    ExitCode: Integer;
    StdOut: string;
    StdErr: string;
    DurationMs: Int64;
    TimedOut: Boolean;
    function Succeeded: Boolean; inline;
    function ToText: string;
  end;

  TCliResultArray = array of TCliResult;

  CLI = class
  private
    class function RunProcess(const FileName, Arguments, WorkingDirectory: string;
      TimeoutMs: Integer; Env: TStrings): TCliResult; static;

    class function DefaultShellExe: string; static;
    class function DefaultShellArgs(const CommandText: string): string; static;

    class procedure AddParsedArguments(AProcess: TObject; const Arguments: string); static;
    class function ParseCommandLine(const S: string): TStringArray; static;
  public
    class function RunExe(const FileName, Arguments: string;
      const WorkingDirectory: string = '';
      TimeoutMs: Integer = 120 * 1000;
      Env: TStrings = nil): TCliResult; static;

    class function RunShell(const CommandText: string;
      const WorkingDirectory: string = '';
      TimeoutMs: Integer = 120 * 1000;
      Env: TStrings = nil): TCliResult; static;

    class function RunShellChain(const Commands: array of string;
      const WorkingDirectory: string = '';
      TimeoutMs: Integer = 120 * 1000;
      Env: TStrings = nil): TCliResult; static;

    class function RunShellBatch(const Commands: array of string;
      const WorkingDirectory: string = '';
      TimeoutPerCommandMs: Integer = 120 * 1000;
      StopOnError: Boolean = True;
      Env: TStrings = nil): TCliResultArray; static;

    class function RunExeWithInput(const FileName, Arguments, InputText: string;
      const WorkingDirectory: string = '';
      TimeoutMs: Integer = 120 * 1000;
      Env: TStrings = nil): TCliResult; static;
  end;

implementation

uses
  Process
  ,Pipes
  ;

function TCliResult.Succeeded: Boolean;
begin
  Result := (not TimedOut) and (ExitCode = 0);
end;

function TCliResult.ToText: string;
begin
  Result :=
    '> ' + FileName + ' ' + Arguments + LineEnding +
    'exit=' + IntToStr(ExitCode);

  if TimedOut then
    Result := Result + ' (timeout)';

  Result := Result + LineEnding +
    '--- stdout ---' + LineEnding + StdOut + LineEnding +
    '--- stderr ---' + LineEnding + StdErr;
end;

function StreamReadAvailableToString(AStream: TInputPipeStream): RawByteString;
type
  TBuf = array[0..8191] of Byte;
var
  Buf: TBuf;
  ToRead: LongInt;
  N: LongInt;
begin
  Result := '';
  if AStream = nil then
    Exit;

  while AStream.NumBytesAvailable > 0 do
  begin
    ToRead := AStream.NumBytesAvailable;
    if ToRead > SizeOf(Buf) then
      ToRead := SizeOf(Buf);

    N := AStream.Read(Buf[0], ToRead);
    if N <= 0 then
      Break;

    SetLength(Result, Length(Result) + N);
    Move(Buf[0], Result[Length(Result) - N + 1], N);
  end;
end;

procedure AppendStreamToText(AStream: TInputPipeStream; var Target: RawByteString);
var
  Chunk: RawByteString;
begin
  Chunk := StreamReadAvailableToString(AStream);
  if Chunk <> '' then
    Target := Target + Chunk;
end;

class function CLI.DefaultShellExe: string;
begin
  {$IFDEF Windows}
  Result := 'cmd.exe';
  {$ELSE}
  Result := '/bin/sh';
  {$ENDIF}
end;

class function CLI.DefaultShellArgs(const CommandText: string): string;
begin
  {$IFDEF Windows}
  Result := '/C ' + CommandText;
  {$ELSE}
  Result := '-lc ' + CommandText;
  {$ENDIF}
end;

class function CLI.ParseCommandLine(const S: string): TStringArray;
var
  i, LenS, Count: Integer;
  Ch: Char;
  Current: string;
  InQuotes: Boolean;
  QuoteChar: Char;

  procedure PushCurrent;
  begin
    SetLength(Result, Count + 1);
    Result[Count] := Current;
    Inc(Count);
    Current := '';
  end;

begin
  Result := nil;
  Count := 0;
  Current := '';
  InQuotes := False;
  QuoteChar := #0;

  LenS := Length(S);
  i := 1;

  while i <= LenS do
  begin
    Ch := S[i];

    if InQuotes then
    begin
      if Ch = QuoteChar then
      begin
        InQuotes := False;
        QuoteChar := #0;
      end
      else if (Ch = '\') and (i < LenS) and (S[i + 1] = QuoteChar) then
      begin
        Current := Current + S[i + 1];
        Inc(i);
      end
      else
        Current := Current + Ch;
    end
    else
    begin
      case Ch of
        ' ', #9, #10, #13:
          begin
            if Current <> '' then
              PushCurrent;
          end;
        '"', '''':
          begin
            InQuotes := True;
            QuoteChar := Ch;
          end;
      else
        Current := Current + Ch;
      end;
    end;

    Inc(i);
  end;

  if InQuotes then
    raise Exception.CreateFmt('Unclosed quote in command line: %s', [S]);

  if Current <> '' then
    PushCurrent;
end;

class procedure CLI.AddParsedArguments(AProcess: TObject; const Arguments: string);
var
  P: TProcess;
  Args: TStringArray;
  i: Integer;
begin
  if Arguments = '' then
    Exit;

  if not (AProcess is TProcess) then
    raise Exception.Create('Invalid process object');

  P := TProcess(AProcess);
  Args := ParseCommandLine(Arguments);

  for i := 0 to High(Args) do
    P.Parameters.Add(Args[i]);
end;

// function RunProcess(const FileName, Arguments, WorkingDirectory: string; TimeoutMs: Integer; Env: TStrings): TCliResult; static;
class function CLI.RunProcess(const FileName, Arguments, WorkingDirectory: string;
  TimeoutMs: Integer; Env: TStrings): TCliResult;
const
  POLL_MS = 15;
var
  P: TProcess;
  StartTick, NowTick: QWord;
  OutBytes, ErrBytes: RawByteString;
  WorkDir: string;
  Finished: Boolean;
  Args: TStringArray;
  i: Integer;

  procedure PumpPipes;
  begin
    AppendStreamToText(P.Output, OutBytes);
    AppendStreamToText(P.Stderr, ErrBytes);
  end;

begin
  Result.FileName := FileName;
  Result.Arguments := Arguments;
  Result.ExitCode := -1;
  Result.StdOut := '';
  Result.StdErr := '';
  Result.DurationMs := 0;
  Result.TimedOut := False;

  WorkDir := Trim(WorkingDirectory);
  if WorkDir = '' then
    WorkDir := GetCurrentDir;

  OutBytes := '';
  ErrBytes := '';

  P := TProcess.Create(nil);
  try
    P.Executable := FileName;
    P.Parameters.Clear;

    Args := ParseCommandLine(Arguments);
    for i := 0 to High(Args) do
      P.Parameters.Add(Args[i]);

    P.Options := [poUsePipes];
    P.CurrentDirectory := WorkDir;

    if Env <> nil then
    begin
      P.Environment.AddStrings(Env);    // όχι Clear, εκτός αν θες να χάσεις PATH/HOME/LANG κλπ
    end;

    StartTick := GetTickCount64;

    try
      P.Execute;
    except
      on E: Exception do
      begin
        Result.ExitCode := -1;
        Result.StdErr := E.Message;
        Exit;
      end;
    end;

    Finished := False;
    repeat
      PumpPipes;

      Finished := P.WaitOnExit(POLL_MS);
      if Finished then
        Break;

      if TimeoutMs > 0 then
      begin
        NowTick := GetTickCount64;
        if (NowTick - StartTick) >= QWord(TimeoutMs) then
        begin
          Result.TimedOut := True;
          try
            P.Terminate(1);
          except
          end;

          try
            P.WaitOnExit(1000);
          except
          end;

          Break;
        end;
      end;
    until False;

    PumpPipes;

    Result.DurationMs := Int64(GetTickCount64 - StartTick);

    if Result.TimedOut then
      Result.ExitCode := -1
    else
      Result.ExitCode := P.ExitStatus;

    Result.StdOut := string(OutBytes);
    Result.StdErr := string(ErrBytes);

    if Result.TimedOut and (Result.StdErr = '') then
      Result.StdErr := 'Timeout';
  finally
    P.Free;
  end;
end;

class function CLI.RunExe(const FileName, Arguments, WorkingDirectory: string;
  TimeoutMs: Integer; Env: TStrings): TCliResult;
begin
  Result := RunProcess(FileName, Arguments, WorkingDirectory, TimeoutMs, Env);
end;

class function CLI.RunShell(const CommandText, WorkingDirectory: string;
  TimeoutMs: Integer; Env: TStrings): TCliResult;
begin
  Result := RunProcess(DefaultShellExe, DefaultShellArgs(CommandText), WorkingDirectory, TimeoutMs, Env);
end;

class function CLI.RunShellChain(const Commands: array of string;
  const WorkingDirectory: string; TimeoutMs: Integer; Env: TStrings): TCliResult;
var
  i: Integer;
  Chain: string;
begin
  Chain := '';
  for i := Low(Commands) to High(Commands) do
  begin
    if Trim(Commands[i]) = '' then
      Continue;
    if Chain <> '' then
      Chain := Chain + ' && ';
    Chain := Chain + Commands[i];
  end;

  Result := RunShell(Chain, WorkingDirectory, TimeoutMs, Env);
end;

class function CLI.RunShellBatch(const Commands: array of string;
  const WorkingDirectory: string; TimeoutPerCommandMs: Integer;
  StopOnError: Boolean; Env: TStrings): TCliResultArray;
var
  i, n: Integer;
  R: TCliResult;
  Res: TCliResultArray;
begin
  Res := nil;
  n := 0;

  for i := Low(Commands) to High(Commands) do
  begin
    if Trim(Commands[i]) = '' then
      Continue;

    R := RunShell(Commands[i], WorkingDirectory, TimeoutPerCommandMs, Env);

    SetLength(Res, n + 1);
    Res[n] := R;
    Inc(n);

    if StopOnError and (not R.Succeeded) then
      Break;
  end;

  Result := Res;
end;

class function CLI.RunExeWithInput(const FileName, Arguments, InputText: string;
  const WorkingDirectory: string; TimeoutMs: Integer; Env: TStrings): TCliResult;
const
  POLL_MS = 15;
var
  P: TProcess;
  StartTick, NowTick: QWord;
  OutBytes, ErrBytes: RawByteString;
  InBytes: RawByteString;
  WorkDir: string;
  Finished: Boolean;
  Args: TStringArray;
  i: Integer;
  Written, N: LongInt;
begin
  Result.FileName := FileName;
  Result.Arguments := Arguments;
  Result.ExitCode := -1;
  Result.StdOut := '';
  Result.StdErr := '';
  Result.DurationMs := 0;
  Result.TimedOut := False;

  WorkDir := Trim(WorkingDirectory);
  if WorkDir = '' then
    WorkDir := GetCurrentDir;

  OutBytes := '';
  ErrBytes := '';
  InBytes := UTF8Encode(InputText);

  P := TProcess.Create(nil);
  try
    P.Executable := FileName;
    P.Parameters.Clear;

    Args := ParseCommandLine(Arguments);
    for i := 0 to High(Args) do
      P.Parameters.Add(Args[i]);

    P.Options := [poUsePipes];
    P.CurrentDirectory := WorkDir;

    if Env <> nil then
      P.Environment.AddStrings(Env);

    StartTick := GetTickCount64;

    try
      P.Execute;
    except
      on E: Exception do
      begin
        Result.ExitCode := -1;
        Result.StdErr := E.Message;
        Exit;
      end;
    end;

    if InBytes <> '' then
    begin
      Written := 1;
      while Written <= Length(InBytes) do
      begin
        N := P.Input.Write(InBytes[Written], Length(InBytes) - Written + 1);
        if N <= 0 then
          Break;
        Inc(Written, N);
      end;
    end;

    P.CloseInput;

    Finished := False;
    repeat
      AppendStreamToText(P.Output, OutBytes);
      AppendStreamToText(P.Stderr, ErrBytes);

      Finished := P.WaitOnExit(POLL_MS);
      if Finished then
        Break;

      if TimeoutMs > 0 then
      begin
        NowTick := GetTickCount64;
        if (NowTick - StartTick) >= QWord(TimeoutMs) then
        begin
          Result.TimedOut := True;
          try
            P.Terminate(1);
          except
          end;
          Break;
        end;
      end;
    until False;

    AppendStreamToText(P.Output, OutBytes);
    AppendStreamToText(P.Stderr, ErrBytes);

    Result.DurationMs := Int64(GetTickCount64 - StartTick);

    if Result.TimedOut then
      Result.ExitCode := -1
    else
      Result.ExitCode := P.ExitStatus;

    Result.StdOut := string(OutBytes);
    Result.StdErr := string(ErrBytes);

    if Result.TimedOut and (Result.StdErr = '') then
      Result.StdErr := 'Timeout';
  finally
    P.Free;
  end;
end;

end.
