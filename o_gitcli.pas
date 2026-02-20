unit o_GitCli;

{$MODE Delphi}{$H+}

interface

uses
  SysUtils, Classes, o_Cli;

type
  { full static class }
  GitCli = class
  public
    class function Git(const GitArguments, RepoDir: string;
      TimeoutMs: Integer = 120 * 1000;
      Env: TStrings = nil): TCliResult; static;

    class function GitBatch(const GitArgsList: array of string; const RepoDir: string;
      TimeoutPerCommandMs: Integer = 120 * 1000;
      StopOnError: Boolean = True;
      Env: TStrings = nil): TCliResultArray; static;

    class function IsGitRepo(const ProjectFolderPath: string): Boolean; static;
    class function EnsureIsRepo(const ProjectFolderPath: string): Boolean; static;
    class function HasUncommittedChanges(const ProjectFolderPath: string): Boolean; static;

    class function CommitIfNeeded(const ProjectFolderPath: string;
      const MessageText: string = ''): Boolean; static;

    class function Push(const RepoDir: string;
      const RemoteName: string = 'origin';
      const Branch: string = 'main';
      TimeoutMs: Integer = 120 * 1000): TCliResult; static;
  end;

implementation

function TrimLineEndings(const S: string): string;
begin
  Result := StringReplace(S, #13, '', [rfReplaceAll]);
end;

function HasRemote(const RemoteListText, RemoteName: string): Boolean;
var
  SL: TStringList;
  i: Integer;
  Line: string;
begin
  Result := False;
  SL := TStringList.Create;
  try
    SL.Text := TrimLineEndings(RemoteListText);
    for i := 0 to SL.Count - 1 do
    begin
      Line := Trim(SL[i]);
      if SameText(Line, RemoteName) then
        Exit(True);
    end;
  finally
    SL.Free;
  end;
end;

class function GitCli.Git(const GitArguments, RepoDir: string;
  TimeoutMs: Integer; Env: TStrings): TCliResult;
begin
  Result := CLI.RunExe('git', GitArguments, RepoDir, TimeoutMs, Env);
end;

class function GitCli.GitBatch(const GitArgsList: array of string; const RepoDir: string;
  TimeoutPerCommandMs: Integer; StopOnError: Boolean; Env: TStrings): TCliResultArray;
var
  i, n: Integer;
  R: TCliResult;
  Res: TCliResultArray;
begin
  Res := nil;
  n := 0;

  for i := Low(GitArgsList) to High(GitArgsList) do
  begin
    if Trim(GitArgsList[i]) = '' then
      Continue;

    R := Git(GitArgsList[i], RepoDir, TimeoutPerCommandMs, Env);

    SetLength(Res, n + 1);
    Res[n] := R;
    Inc(n);

    if StopOnError and (not R.Succeeded) then
      Break;
  end;

  Result := Res;
end;

class function GitCli.IsGitRepo(const ProjectFolderPath: string): Boolean;
begin
  Result := DirectoryExists(IncludeTrailingPathDelimiter(ProjectFolderPath) + '.git');
end;

class function GitCli.EnsureIsRepo(const ProjectFolderPath: string): Boolean;
var
  GitFolder: string;
  R: TCliResult;
begin
  if (Trim(ProjectFolderPath) = '') or (not DirectoryExists(ProjectFolderPath)) then
    raise Exception.CreateFmt('Folder not exists: %s', [ProjectFolderPath]);

  GitFolder := IncludeTrailingPathDelimiter(ProjectFolderPath) + '.git';
  if DirectoryExists(GitFolder) then
    Exit(True);

  R := Git('init', ProjectFolderPath);
  if not R.Succeeded then
    raise Exception.CreateFmt('Failed to ''git init'' in folder: %s', [ProjectFolderPath]);

  // force main (for older git)
  R := Git('symbolic-ref HEAD refs/heads/main', ProjectFolderPath);
  if not R.Succeeded then
    raise Exception.CreateFmt('Warning cannot set HEAD to ''main'': %s'#10'%s', [ProjectFolderPath, R.StdErr]);

  R := Git('add .', ProjectFolderPath);
  if not R.Succeeded then
    raise Exception.CreateFmt('Failed to ''git add'' in folder: %s'#10'%s', [ProjectFolderPath, R.StdErr]);

  R := Git('commit -m "Initial commit"', ProjectFolderPath);
  if not R.Succeeded then
    raise Exception.CreateFmt('Failed to ''git commit'' in folder: %s'#10'%s', [ProjectFolderPath, R.StdErr]);

  Result := True;
end;

class function GitCli.HasUncommittedChanges(const ProjectFolderPath: string): Boolean;
var
  R: TCliResult;
begin
  if (Trim(ProjectFolderPath) = '') or (not DirectoryExists(ProjectFolderPath)) then
    raise Exception.CreateFmt('Folder not exists: %s', [ProjectFolderPath]);

  if not IsGitRepo(ProjectFolderPath) then
    raise Exception.CreateFmt('Folder is not a git repo: %s', [ProjectFolderPath]);

  R := Git('status --porcelain', ProjectFolderPath);
  if not R.Succeeded then
    raise Exception.CreateFmt('Failed to ''git status'':'#10'%s', [R.StdErr]);

  Result := Trim(R.StdOut) <> '';
end;

class function GitCli.CommitIfNeeded(const ProjectFolderPath: string; const MessageText: string): Boolean;
var
  Msg: string;
  DT: string;
  R: TCliResult;
begin
  if not HasUncommittedChanges(ProjectFolderPath) then
    Exit(False);

  R := Git('add -A', ProjectFolderPath);
  if not R.Succeeded then
    raise Exception.CreateFmt('Failed to ''git add'':'#10'%s', [R.StdErr]);

  Msg := Trim(MessageText);
  if Msg = '' then
  begin
    DT := FormatDateTime('yyyy"-"mm"-"dd hh":"nn":"ss', Now);
    Msg := 'Auto-commit ' + DT;
  end;

  // basic quoting. If you may have quotes in Msg, we can escape them.
  R := Git('commit -m "' + Msg + '"', ProjectFolderPath);
  if not R.Succeeded then
    raise Exception.CreateFmt('Failed to ''git commit'':'#10'%s', [R.StdErr]);

  Result := True;
end;

class function GitCli.Push(const RepoDir, RemoteName, Branch: string; TimeoutMs: Integer): TCliResult;
var
  R: TCliResult;
begin
  if (Trim(RepoDir) = '') or (not DirectoryExists(RepoDir)) then
    raise Exception.CreateFmt('Folder not exists: %s', [RepoDir]);

  if not IsGitRepo(RepoDir) then
    raise Exception.CreateFmt('Folder is not a git repo: %s', [RepoDir]);

  R := Git('remote', RepoDir, TimeoutMs);
  if not R.Succeeded then
    raise Exception.CreateFmt('Failed to check git remotes:'#10'%s', [R.StdErr]);

  if not HasRemote(R.StdOut, RemoteName) then
    raise Exception.CreateFmt('Remote ''%s'' not found in repo: %s', [RemoteName, RepoDir]);

  Result := Git(Format('push %s %s', [RemoteName, Branch]), RepoDir, TimeoutMs);
  if not Result.Succeeded then
    raise Exception.CreateFmt('Failed to push branch ''%s'' to ''%s'':'#10'%s', [Branch, RemoteName, Result.StdErr]);
end;

end.
