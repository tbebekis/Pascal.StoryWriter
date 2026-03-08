unit f_TempTextForm;

{$mode ObjFPC}{$H+}

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
  , DBCtrls
  , DBGrids
  , f_PageForm
  , Tripous.MemTable
  , Tripous.Broadcaster
  , o_Entities
  , f_TextEditorForm
  , o_TextEditor
  ;

type

  { TTempTextForm }

  TTempTextForm = class(TPageForm)
  private
    frmText: TTextEditorForm;

    procedure ReLoad();
  protected
    procedure FormInitialize(); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;

    procedure AdjustTabTitle(); override;
    procedure SaveEditorText(TextEditor: TTextEditor); override;
  end;


implementation

{$R *.lfm}

uses
   Tripous
  ,Tripous.Logs
  ,o_App
  ;



constructor TTempTextForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  frmText := TTextEditorForm.Create(Self);
  frmText.Parent := Self;
  frmText.FramePage := Self;
end;

destructor TTempTextForm.Destroy();
begin
  inherited Destroy();
end;

procedure TTempTextForm.FormInitialize();
begin
  frmText.Visible := True;
  TitleText := 'Temp Text';
  ParentTabPage.Caption := TitleText;

  ReLoad();

  AdjustTabTitle();

end;

procedure TTempTextForm.AdjustTabTitle();
begin
  if frmText.Modified  then
     frmText.Title := TitleText + '*'
  else
     frmText.Title := TitleText;
end;

procedure TTempTextForm.SaveEditorText(TextEditor: TTextEditor);
var
  Message: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  if TextEditor = frmText.TextEditor then
  begin
    App.CurrentProject.TempText := frmText.TextEditor.EditorText;
    App.CurrentProject.SaveTempText();
    TextEditor.Modified := False;

    Message := Format('Temp Doc. Text saved: %s.', [App.CurrentProject.TempFilePath]);
  end;

  LogBox.AppendLine(Message);

  AdjustTabTitle();
end;

procedure TTempTextForm.ReLoad();
var
  //S: string;
  Message: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  frmText.EditorText := '';

  if FileExists(App.CurrentProject.TempFilePath) then
  begin
    App.CurrentProject.LoadTempText();
    //S := Sys.LoadFromFile(App.CurrentProject.TempFilePath);
    frmText.EditorText := App.CurrentProject.TempText;

    Message := Format('Temp Doc. Text loaded from: %s', [App.CurrentProject.TempFilePath]);
    LogBox.AppendLine(Message);
  end;
end;

end.

