unit f_GitCommitMessageDialog;

{$mode DELPHI}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls;

type

  { TGitCommitMessageDialog }

  TGitCommitMessageDialog = class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    edtMessage: TEdit;
    Label1: TLabel;
  protected
    procedure AnyClick(Sender: TObject);
    procedure FormInitialize();
    procedure ItemToControls();
    procedure ControlsToItem();
    procedure DoShow; override;
  public
    class function ShowDialog(var CommitMessage: string): Boolean;
  end;


implementation

{$R *.lfm}

{ TGitCommitMessageDialog }

class function TGitCommitMessageDialog.ShowDialog(var CommitMessage: string): Boolean;
var
  Dlg: TGitCommitMessageDialog;
begin
  Result := False;

  Dlg := TGitCommitMessageDialog.Create(nil);
  try
    Dlg.edtMessage.Text  := CommitMessage;
    Result := Dlg.ShowModal() = mrOk;
    if Result then
    begin
      CommitMessage := Trim(Dlg.edtMessage.Text);
    end;
  finally
    Dlg.Free;
  end;

end;

procedure TGitCommitMessageDialog.DoShow;
begin
  inherited DoShow;
  FormInitialize();
end;

procedure TGitCommitMessageDialog.FormInitialize();
begin
  btnOK.Default := True;
  btnCancel.Cancel := True;
  btnOK.OnClick := AnyClick;

  ItemToControls();
end;

procedure TGitCommitMessageDialog.ItemToControls();
begin
end;

procedure TGitCommitMessageDialog.ControlsToItem();
begin
  if Trim(edtMessage.Text) <> '' then
    Self.ModalResult := mrOK;
end;

procedure TGitCommitMessageDialog.AnyClick(Sender: TObject);
begin
  if btnOK = Sender then
    ControlsToItem();
end;









end.

