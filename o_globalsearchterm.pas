unit o_GlobalSearchTerm;

{$MODE Delphi}{$H+}

interface

uses
  SysUtils, SynEdit;

function GetSelectedTerm(Syn: TSynEdit): string;

implementation

uses
  LazUTF8;

function IsWordCodePoint(U: Cardinal): Boolean; inline;
begin
  // underscore
  if U = Ord('_') then Exit(True);

  // ASCII digits
  if (U >= Ord('0')) and (U <= Ord('9')) then Exit(True);

  // ASCII letters
  if ((U >= Ord('A')) and (U <= Ord('Z'))) or
     ((U >= Ord('a')) and (U <= Ord('z'))) then Exit(True);

  // Greek & Greek Extended
  if ((U >= $0370) and (U <= $03FF)) or
     ((U >= $1F00) and (U <= $1FFF)) then Exit(True);

  // Latin Extended
  if (U >= $00C0) and (U <= $02AF) then Exit(True);

  Result := False;
end;

function IsWordCharUTF8(const Ch: string): Boolean; inline;
var
  U: Cardinal;
  L: Integer;
begin
  if Ch = '' then
    Exit(False);

  U := UTF8CodepointToUnicode(PChar(Ch), L);
  Result := IsWordCodePoint(U);
end;

function GetWordAtCaretUTF8(Syn: TSynEdit): string;
var
  LineText: string;
  CaretCol: Integer;   // 1-based UTF8 char index
  Len, i1, i2: Integer;
  Ch: string;
begin
  Result := '';

  if Syn = nil then Exit;
  if (Syn.CaretY < 1) or (Syn.CaretY > Syn.Lines.Count) then Exit;

  LineText := Syn.Lines[Syn.CaretY - 1];
  if LineText = '' then Exit;

  Len := UTF8Length(LineText);
  if Len = 0 then Exit;

  CaretCol := Syn.CaretX;
  if CaretCol < 1 then CaretCol := 1;
  if CaretCol > Len then CaretCol := Len;

  Ch := UTF8Copy(LineText, CaretCol, 1);

  // Αν δεν είναι πάνω σε word char, δοκίμασε αριστερά
  if not IsWordCharUTF8(Ch) then
  begin
    if CaretCol > 1 then
    begin
      Dec(CaretCol);
      Ch := UTF8Copy(LineText, CaretCol, 1);
      if not IsWordCharUTF8(Ch) then Exit;
    end
    else
      Exit;
  end;

  // Expand left
  i1 := CaretCol;
  while (i1 > 1) and IsWordCharUTF8(UTF8Copy(LineText, i1 - 1, 1)) do
    Dec(i1);

  // Expand right
  i2 := CaretCol;
  while (i2 < Len) and IsWordCharUTF8(UTF8Copy(LineText, i2 + 1, 1)) do
    Inc(i2);

  Result := UTF8Copy(LineText, i1, i2 - i1 + 1);
end;

function SelectionLooksLikeSingleTerm(const S: string): Boolean;
begin
  Result :=
    (S <> '') and
    (Pos(' ', S) = 0) and
    (Pos(#9, S) = 0) and
    (Pos(#10, S) = 0) and
    (Pos(#13, S) = 0);
end;

function GetSelectedTerm(Syn: TSynEdit): string;
var
  Sel: string;
begin
  Result := '';
  if Syn = nil then Exit;

  Sel := Trim(Syn.SelText);

  if SelectionLooksLikeSingleTerm(Sel) then
    Result := Sel
  else
    Result := Trim(GetWordAtCaretUTF8(Syn));
end;

end.
