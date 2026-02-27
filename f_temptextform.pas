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
  , StdCtrls
  , Contnrs
  , Menus
  , DB
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
    procedure TitleChanged(); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy(); override;
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

  //TextEditor := TTextEditor.Create(Self);
  //TextEditor.Parent := Self;
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

procedure TTempTextForm.TitleChanged();
begin
  inherited TitleChanged();
  frmText.Title := TitleText;
end;

procedure TTempTextForm.ReLoad();
var
  S: string;
  Message: string;
begin
  if not Assigned(App.CurrentProject) then
    Exit;

  frmText.TextEditor.EditorText := '';

  if FileExists(App.CurrentProject.TempFilePath) then
  begin
    S := Sys.LoadFromFile(App.CurrentProject.TempFilePath);
    frmText.TextEditor.EditorText := S;

    Message := Format('Temp Doc. Text loaded from: %s', [App.CurrentProject.TempFilePath]);
    LogBox.AppendLine(Message);
  end;
end;

end.

