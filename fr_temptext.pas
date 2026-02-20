unit fr_TempText;

{$MODE DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , ExtCtrls
  , ComCtrls
  , Menus
  , LCLType
  , LCLIntf
  , DBCtrls
  , DBGrids
  , fr_FramePage
  , Tripous.MemTable
  , o_Entities
  , fr_TextEditor
  ;

type

  { TfrTempText }

  TfrTempText = class(TFramePage)
    frText: TfrTextEditor;
  private
    TitleText: string;

    procedure ReLoad();
  public
    procedure ControlInitialize; override;
    procedure ControlInitializeAfter(); override;

    { editor handler }
    procedure SaveEditorText(TextEditor: TfrTextEditor); override;
  end;

implementation

{$R *.lfm}

uses
   Tripous
  ,Tripous.Logs
  ,o_App
  ;

{ TfrTempText }

procedure TfrTempText.ControlInitialize;
begin
  inherited ControlInitialize;

  TitleText := 'Temp Text';
  ParentTabPage.Caption := 'Temp Text';

  ReLoad();
  AdjustTabTitle();
end;

procedure TfrTempText.ControlInitializeAfter();
begin
end;

procedure TfrTempText.ReLoad();
var
  S: string;
  Message: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  frText.EditorText := '';

  if FileExists(App.CurrentProject.TempFilePath) then
  begin
    S := Sys.LoadFromFile(App.CurrentProject.TempFilePath);
    frText.EditorText := S;

    Message := Format('Temp Doc. Text loaded from: %s', [App.CurrentProject.TempFilePath]);
    LogBox.AppendLine(Message);
  end;
end;

procedure TfrTempText.SaveEditorText(TextEditor: TfrTextEditor);
var
  Message: string;
begin

  if not Assigned(App.CurrentProject) then
    Exit;

  if TextEditor = frText then
  begin
    App.CurrentProject.TempText := TextEditor.EditorText;
    App.CurrentProject.SaveTempText();
    Message := Format('Temp Text saved to: %s.', [App.CurrentProject.TempFilePath]);
    LogBox.AppendLine(Message);
  end;

  TextEditor.Modified := False;
  AdjustTabTitle();
end;



end.

