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
  , StdCtrls
  , Contnrs
  , Menus
  , LCLType
  , LCLIntf
  , DB
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

    // ● event handler
    procedure AppOnProjectOpened(Sender: TObject);
    procedure AppOnProjectClosed(Sender: TObject);


    procedure ReLoad();

  public
    procedure ControlInitialize; override;
    procedure ControlInitializeAfter(); override;
    { editor handler }
    procedure SaveEditorText(TextEditor: TfrTextEditor); override;
    procedure GlobalSearchForTerm(const Term: string); override;
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

  App.OnProjectOpened := AppOnProjectOpened;
  App.OnProjectClosed := AppOnProjectClosed;

  AdjustTabTitle();
end;

procedure TfrTempText.ControlInitializeAfter();
begin
  inherited ControlInitializeAfter();
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
begin
  inherited SaveEditorText(TextEditor);
end;

procedure TfrTempText.AppOnProjectOpened(Sender: TObject);
begin

end;

procedure TfrTempText.AppOnProjectClosed(Sender: TObject);
begin

end;

procedure TfrTempText.GlobalSearchForTerm(const Term: string);
begin
  inherited GlobalSearchForTerm(Term);
end;

end.

