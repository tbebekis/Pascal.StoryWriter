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

  { full static class }
  CLI = class
  private
    class function RunProcess(const FileName, Arguments, WorkingDirectory: string;
      TimeoutMs: Integer; Env: TStrings): TCliResult; static;

    class function DefaultShellExe: string; static;
    class function DefaultShellArgs(const CommandText: string): string; static;
  public
    { Runs executable directly (e.g. git) with arguments. }
    class function RunExe(const FileName, Arguments: string;
      const WorkingDirectory: string = '';
      TimeoutMs: Integer = 120 * 1000;
      Env: TStrings = nil): TCliResult; static;

    { Runs a single command through OS shell (Windows: cmd.exe /C, *nix: /bin/sh -lc). }
    class function RunShell(const CommandText: string;
      const WorkingDirectory: string = '';
      TimeoutMs: Integer = 120 * 1000;
      Env: TStrings = nil): TCliResult; static;

    { Runs multiple shell commands in ONE shell, bound with && (stops if any fails). }
    class function RunShellChain(const Commands: array of string;
      const WorkingDirectory: string = '';
      TimeoutMs: Integer = 120 * 1000;
      Env: TStrings = nil): TCliResult; static;

    { Runs a series of shell commands. Stops on first error unless StopOnError=false. }
    class function RunShellBatch(const Commands: array of string;
      const WorkingDirectory: string = '';
      TimeoutPerCommandMs: Integer = 120 * 1000;
      StopOnError: Boolean = True;
      Env: TStrings = nil): TCliResultArray; static;
  end;

implementation

uses
  Process;

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

function StreamReadAvailableToString(AStream: TStream): RawByteString;
type
  TBuf = array[0..8191] of Byte;
var
  Buf: TBuf;
  N: LongInt;
begin
  Buf := Default(TBuf);   // σβήνει το hint (ναι, είναι χαζό αλλά δουλεύει)
  Result := '';
  if AStream = nil then
    Exit;

  while True do
  begin
    N := AStream.Read(Buf[0], SizeOf(Buf));
    if N <= 0 then
      Break;

    SetLength(Result, Length(Result) + N);
    Move(Buf[0], Result[Length(Result) - N + 1], N);
  end;
end;

procedure AppendStreamToText(AStream: TStream; var Target: RawByteString);
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
  // Use /bin/sh by convention; if unavailable, user can call RunExe('sh', ...)
  Result := '/bin/sh';
  {$ENDIF}
end;

class function CLI.DefaultShellArgs(const CommandText: string): string;
begin
  {$IFDEF Windows}
  Result := '/C ' + CommandText;
  {$ELSE}
  // -l: login shell (optional), -c: run command string
  Result := '-lc ' + CommandText;
  {$ENDIF}
end;

class function CLI.RunProcess(const FileName, Arguments, WorkingDirectory: string;
  TimeoutMs: Integer; Env: TStrings): TCliResult;
const
  POLL_MS = 15;
var
  P: TProcess;
  StartTick: QWord;
  NowTick: QWord;
  OutBytes, ErrBytes: RawByteString;
  WorkDir: string;

  procedure PumpPipes;
  begin
    // Read what is currently available to avoid pipe deadlocks.
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

    if Arguments <> '' then
      P.Parameters.Add(Arguments);

    P.Options := [poUsePipes, poStderrToOutPut]; // we will still read Stderr stream if not redirected
    // poStderrToOutPut merges streams; remove it if you want strict separation.
    // We keep it to avoid platform-specific stderr pipe issues, and we still expose StdErr if available.

    P.CurrentDirectory := WorkDir;

    if Env <> nil then
    begin
      P.Environment.Clear;
      P.Environment.AddStrings(Env);
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

    // Main wait loop (blocking) with timeout + pumping pipes
    while P.Running do
    begin
      PumpPipes;

      if TimeoutMs > 0 then
      begin
        NowTick := GetTickCount64;
        if (NowTick - StartTick) >= QWord(TimeoutMs) then
        begin
          Result.TimedOut := True;
          try
            P.Terminate(1);
          except
            // ignore
          end;
          Break;
        end;
      end;

      Sleep(POLL_MS);
    end;

    // Ensure process exited (or was terminated)
    try
      P.WaitOnExit(1000);
    except
      // ignore
    end;

    // Drain remaining output
    PumpPipes;

    // Exit code
    if Result.TimedOut then
      Result.ExitCode := -1
    else
      Result.ExitCode := P.ExitStatus;

    Result.DurationMs := Int64(GetTickCount64 - StartTick);

    // Convert raw bytes (assume UTF-8; Lazarus strings are UTF-8 typically)
    Result.StdOut := string(OutBytes);

    // If stderr was merged, keep StdErr empty; otherwise provide captured bytes.
    if ErrBytes <> '' then
      Result.StdErr := string(ErrBytes)
    else if Result.TimedOut then
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

end.
