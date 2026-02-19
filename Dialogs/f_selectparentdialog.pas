unit f_SelectParentDialog;

{$mode DELPHI}{$H+}

interface

uses
  Classes
  , SysUtils
  , Forms
  , Controls
  , Graphics
  , Dialogs
  , StdCtrls
  , Contnrs
  , o_Entities
  ;

type

  { TSelectParentDialog }

  TSelectParentDialog = class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    edtItem: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    lboAvailParents: TListBox;
  private
    Item: TBaseItem;
    ItemList: TObjectList;
  protected
    procedure AnyClick(Sender: TObject);
    procedure FormInitialize();
    procedure ItemToControls();
    procedure ControlsToItem();
    procedure DoShow; override;
  public
    class function ShowDialog(AItem: TBaseItem; AItemList: TObjectList; var ResultItem: TBaseItem): Boolean;
  end;



implementation

{$R *.lfm}



{ TSelectParentDialog }

class function TSelectParentDialog.ShowDialog(AItem: TBaseItem; AItemList: TObjectList; var ResultItem: TBaseItem): Boolean;
var
  Dlg: TSelectParentDialog;
begin
  Result := False;

  Dlg := TSelectParentDialog.Create(nil);
  try
    Dlg.Caption := 'Select Parent for';
    Dlg.Item := AItem;
    Dlg.ItemList := AItemList;
    Result := Dlg.ShowModal() = mrOk;
    if Result then
    begin
      ResultItem := Dlg.Item;
    end;
  finally
    Dlg.Free;
  end;

end;

procedure TSelectParentDialog.DoShow;
begin
  inherited DoShow;
  FormInitialize();
end;

procedure TSelectParentDialog.FormInitialize();
begin
  btnOK.Default := True;
  btnCancel.Cancel := True;
  btnOK.OnClick := AnyClick;

  ItemToControls();
end;

procedure TSelectParentDialog.ItemToControls();
var
  i : Integer;
  Title: string;
begin
  edtItem.Text := Item.Title ;

  for i := 0 to ItemList.Count - 1 do
  begin
    Title := TBaseItem(ItemList[i]).Title;
    lboAvailParents.Items.Add(Title);
  end;

  if ItemList.Count > 0 then
    lboAvailParents.ItemIndex := 0;
end;

procedure TSelectParentDialog.ControlsToItem();
begin
  if lboAvailParents.ItemIndex <> -1 then
  begin
    Item := ItemList[lboAvailParents.ItemIndex] as TBaseItem;
  end;
end;

procedure TSelectParentDialog.AnyClick(Sender: TObject);
begin
  if btnOK = Sender then
    ControlsToItem();
end;








end.

