unit main;

interface

uses
  // Delphi
  System.Classes,
  System.Rtti,
  System.SysUtils,
  // FireMonkey
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Edit,
  FMX.Forms,
  FMX.Graphics,
  FMX.Grid,
  FMX.Grid.Style,
  FMX.ListBox,
  FMX.ScrollBox,
  FMX.StdCtrls,
  FMX.Types,
  // web3
  web3,
  web3.eth.tokenlists,
  web3.eth.types;

type
  TfrmMain = class(TForm)
    lblAddress: TLabel;
    edtAddress: TEdit;
    cboChain: TComboBox;
    btnScan: TButton;
    Grid: TGrid;
    colCheck: TCheckColumn;
    colImage: TImageColumn;
    colName: TStringColumn;
    procedure btnScanClick(Sender: TObject);
    procedure GridGetValue(Sender: TObject; const ACol, ARow: Integer;
      var Value: TValue);
  private
    FBitmaps: TArray<TBitmap>;
    FChecked: TArray<Boolean>;
    FTokens: TArray<IToken>;
    procedure Address(callback: TAsyncAddress);
    function Chain: TChain;
    function Client: IWeb3;
    procedure Enumerate(foreach: TProc<Integer, TProc>; done: TProc);
    class function Ethereum: IWeb3;
    procedure InitUI;
    class procedure Synchronize(P: TThreadProcedure);
    procedure UpdateUI;
  public
    constructor Create(aOwner: TComponent); override;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

uses
  // Delphi
  System.Net.HttpClient,
  // web3
  web3.eth,
  web3.eth.infura,
  web3.http,
  // Project
  common;

//------------------------------- event handlers -------------------------------

procedure TfrmMain.btnScanClick(Sender: TObject);
begin
  UpdateUI;
end;

procedure TfrmMain.GridGetValue(Sender: TObject; const ACol, ARow: Integer;
  var Value: TValue);
begin
  case ACol of
    0: Value := FChecked[ARow];
    1: Value := FBitmaps[ARow];
    2: Value := FTokens[ARow].Name;
  end;
end;

{ public }

constructor TfrmMain.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  InitUI;
end;

//---------------------------------- private -----------------------------------

procedure TfrmMain.Address(callback: TAsyncAddress);
begin
  if edtAddress.Text.Length = 0 then
    callback(EMPTY_ADDRESS, nil)
  else
    TAddress.New(Ethereum, edtAddress.Text, callback);
end;

function TfrmMain.Chain: TChain;
begin
  Result := TChain(cboChain.Items.Objects[cboChain.ItemIndex]);
end;

function TfrmMain.Client: IWeb3;
begin
  Result := TWeb3.Create(Chain, web3.eth.infura.endpoint(Chain, INFURA_PROJECT_ID));
end;

class function TfrmMain.Ethereum: IWeb3;
begin
  Result := TWeb3.Create(web3.Ethereum, web3.eth.infura.endpoint(web3.Ethereum, INFURA_PROJECT_ID));
end;

procedure TfrmMain.InitUI;
begin
  for var C in CHAINS do
    cboChain.Items.AddObject(C.Name, TObject(C));
  cboChain.ItemIndex := 0;
  edtAddress.SetFocus;
end;

procedure TfrmMain.Enumerate(foreach: TProc<Integer, TProc>; done: TProc);
begin
  var next: TProc<Integer>;

  next := procedure(idx: Integer)
  begin
    if idx >= Length(FTokens) then
    begin
      if Assigned(done) then done;
      EXIT;
    end;
    foreach(idx, procedure
    begin
      next(idx + 1);
    end);
  end;

  if Length(FTokens) = 0 then
  begin
    if Assigned(done) then done;
    EXIT;
  end;

  next(0);
end;

class procedure TfrmMain.Synchronize(P: TThreadProcedure);
begin
  if TThread.CurrentThread.ThreadID = MainThreadId then
    P
  else
    TThread.Synchronize(nil, procedure
    begin
      P
    end);
end;

procedure TfrmMain.UpdateUI;
begin
  tokens(Chain, procedure(tokens: TArray<IToken>; err: IError)
  begin
    if Assigned(err) then
    begin
      ShowError(err, Chain);
      EXIT;
    end;

    FTokens := tokens;

    SetLength(FChecked, Length(FTokens));
    for var I := 0 to Length(FChecked) - 1 do
      FChecked[I] := True;

    if Length(FBitmaps) > 0 then
    begin
      for var bmp in FBitmaps do
        if Assigned(bmp) then bmp.Free;
      SetLength(FBitmaps, 0);
    end;
    SetLength(FBitmaps, Length(FTokens));

    Enumerate(
      // foreach
      procedure(idx: Integer; next: TProc)
      begin
        if FTokens[idx].LogoURI.IsEmpty then
        begin
          next;
          EXIT;
        end;
        web3.http.get(FTokens[idx].LogoURI.Replace('ipfs://', IPFS_GATEWAY), procedure(image: IHttpResponse; err: IError)
        begin
          if Assigned(err) then
          begin
            next;
            EXIT;
          end;
          FBitmaps[idx] := TBitmap.Create;
          try
            FBitmaps[idx].LoadFromStream(image.ContentStream);
          except end;
          Synchronize(procedure
          begin
            colImage.UpdateCell(idx);
          end);
          next;
        end);
      end,
      // done
      procedure
      begin
      end
    );

    Grid.RowCount := Length(FTokens);
    Self.Invalidate;
  end);
end;

end.
