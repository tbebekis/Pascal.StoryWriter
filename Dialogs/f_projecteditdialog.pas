unit f_ProjectEditDialog;

{$mode Delphi}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , StdCtrls
  , o_Entities
  ;

type

  { TProjectEditDialog }

  TProjectEditDialog = class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    btnSelectFolder: TButton;
    edtTitle: TEdit;
    edtFolderPath: TEdit;
    Label1: TLabel;
    Label2: TLabel;
  private
    Project: TProject;
  protected
    procedure AnyClick(Sender: TObject);
    procedure FormInitialize();
    procedure ItemToControls();
    procedure ControlsToItem();
    procedure DoShow; override;
  public
    class function ShowDialog(AProject: TProject): Boolean;
  end;



implementation

{$R *.lfm}

uses
  o_App
  ;

{ TProjectEditDialog }

class function TProjectEditDialog.ShowDialog(AProject: TProject): Boolean;
var
  Dlg: TProjectEditDialog;
begin
  Result := False;

  Dlg := TProjectEditDialog.Create(nil);
  try
    Dlg.Project := AProject;
    Result := Dlg.ShowModal() = mrOk;
  finally
    Dlg.Free;
  end;
end;

procedure TProjectEditDialog.DoShow;
begin
  inherited DoShow;
  FormInitialize();
end;

procedure TProjectEditDialog.FormInitialize();
begin
  btnOK.Default := True;
  btnCancel.Cancel := True;
  btnOK.OnClick := AnyClick;
  btnSelectFolder.OnClick := AnyClick;
  edtTitle.SetFocus();
  ItemToControls();
end;

procedure TProjectEditDialog.ItemToControls();
begin
  edtTitle.Text := Project.Title;
  edtFolderPath.Text := Project.FolderPath;
end;

procedure TProjectEditDialog.ControlsToItem();
begin
  if (Trim(edtTitle.Text) <> '') and DirectoryExists(Trim(edtFolderPath.Text)) then
  begin
    Project.Title := Trim(edtTitle.Text);
    Project.FolderPath := Trim(edtFolderPath.Text);
    Self.ModalResult := mrOK;
  end;
end;

procedure TProjectEditDialog.AnyClick(Sender: TObject);
var
  FolderPath: string;
begin
  if btnOK = Sender then
    ControlsToItem()
  else if btnSelectFolder = Sender then
  begin
    FolderPath := Trim(edtFolderPath.Text);
    if App.ShowFolderDialog(FolderPath) then
      edtFolderPath.Text := FolderPath;
  end;
end;









end.

