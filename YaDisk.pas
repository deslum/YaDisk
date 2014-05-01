unit YaDisk;

interface

uses
  System.SysUtils, System.Classes, Data.DB, Data.Win.ADODB,idHttp,idSSl,
  IdSSLOpenSSL,IdIOHandler,RegularExpressionsAPI,RegularExpressionsCore,
  RegularExpressionsConsts,RegularExpressions,idGlobalProtocols,idGlobal,
  vcl.dialogs;


type
  TWDav = class(TIdHTTP)
  public
    procedure MkCol(AURL: string);
    procedure Copy(AURL:String);
    procedure Move(AURL:String);
    function Prop(HttpMethod:String;AURL:String;ASource:TStrings):String;
end;

type
  TYaDisk = class(TWDav)
  private
    Http:       TWDav;
    Ssl:        TIdSSLIOHandlerSocketOpenSSL;
    function    RegEx(Str:String;Expression:String):String;
  public
    constructor Create(Login:String;Pass:String);
    destructor  Destroy;
    procedure   Put(FileName:String);
    procedure   Get(FileName:String);
    procedure   Delete(ObjectName:String);
    procedure   MkCol(AURL: String);
    procedure   Copy(InPath,OutPath:String);
    procedure   Folder(FolderName:String;Depth:Integer);
    procedure   Move(InPath,OutPath:String);
    procedure   GetSpaceDisk(var Available: String; var Used: String);
    procedure   GetProperties(ObjectName:String);
    function    Share(FileName:String;Open:Boolean = true):String;
    function    IsShare(FileName:String): Boolean;
    function    GetLogin():String;
  end;

const

USERAGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.7; rv:25.0) Gecko/20100101 Firefox/25.0';
YaURL = 'https://webdav.yandex.ru/';
ApplicationName = 'YaDisk DelphiSDK/0.0.1';
Id_HTTPMethodMkCol = 'MKCOL';
Id_HTTPMethodCopy = 'COPY';
Id_HTTPMethodMove = 'MOVE';
Id_HTTPMethodPropPatch = 'PROPPATCH';
Id_HTTPMethodPropFind = 'PROPFIND';


procedure Register;

implementation

{$REGION 'TWDav'}

function TYaDisk.RegEx(Str:String;Expression: String):String;
var
  Reg:TRegEx;
begin
  Reg:=TRegex.Create(Expression);
  if Reg.IsMatch(Str) then
    Result:=Reg.Match(Str).Value;
end;

procedure TWDav.MkCol(AURL: string);
begin
  DoRequest(Id_HTTPMethodMkCol, AURL, nil, nil, []);
end;

procedure TWdav.Copy(AURL: String);
begin
  DoRequest(Id_HTTPMethodCopy, AURL, nil, nil, []);
end;

procedure TWdav.Move(AURL: String);
begin
  DoRequest(Id_HTTPMethodMove, AURL, nil, nil, []);
end;

function TWdav.Prop(HttpMethod:String;AURL: String;  ASource:TStrings):String;
var
  LResponse, Source: TMemoryStream;
begin
  try
    LResponse := TMemoryStream.Create;
    Source := TMemoryStream.Create;
    if ASource<>nil then
      Asource.SaveToStream(Source);
    DoRequest(HttpMethod, AURL, Source, LResponse, []);
    SetString(Result,PAnsiChar(LResponse.memory),LResponse.Size);
  finally
    FreeAndNil(LResponse);
    FreeAndNil(Source);
  end;
end;

{$ENDREGION}

{$REGION 'TYaDisk'}

constructor TYaDisk.Create(Login:String;Pass:String);
begin
  self.http:=TWDav.Create;
  ssl:=TIdSSLIOHandlerSocketOpenSSL.Create;
  with SSL.SSLOptions do
  begin
    Method:=SslvSSLv3;
    Mode:=sslmUnassigned;
    VerifyMode:=[];
    VerifyDepth:=0;
  end;
  ssl.Host:=String.Empty;
  http.IOHandler:=Ssl;
  try
    with Self.Http.Request do
    begin
      UserAgent:=USERAGENT;
      BasicAuthentication:=True;
      Username:=Login;
      Password:=Pass;
    end;
  except
    on E : Exception do
      ShowMessage(E.ClassName+' '+E.Message);
  end;
end;

destructor TYaDisk.Destroy;
begin
  FreeAndNil(Http);
  FreeAndNil(Ssl);
end;

function TYaDisk.GetLogin:String;
begin
  with Http.Request do
  begin
    UserAgent:=USERAGENT;
    Accept:='*/*';
  end;
  Result:=Http.Get(YaURL+'?userinfo');
end;

procedure TYaDisk.Put(FileName: String);
var
  Stream:TFileStream;
begin
  Stream:=TFileStream.Create(Filename,fmOpenRead);
  with http.Request do
  begin
    CustomHeaders.AddValue('Expect','100-continue');
    ContentType:='application/binary';
    ContentLength:=Stream.Size;
  end;
  Http.Put(YaURL+Filename,Stream);
  Stream.Free;
end;

procedure TYaDisk.Get(FileName: String);
var
  Stream:TStream;
begin
  Stream:=TFileStream.Create(Filename,fmcreate);
  Http.Get(YaURL+Filename,stream);
  Stream.Free;
end;


procedure TYaDisk.MkCol(AURL: String);
begin
  Http.Request.Accept:='*/*';
  Http.MkCol(YaURL+Aurl);
end;

procedure TYaDisk.Delete(ObjectName: String);
begin
  Http.Delete(YaURL+ObjectName);
end;

procedure TYaDisk.Copy(InPath: String; OutPath: String);
begin
 with Http.Request do
  begin
    Accept:='*/*';
    CustomHeaders.AddValue('Destination','/'+InPath);
  end;
  Http.Copy(YaURL+OutPath);
end;

procedure TYaDisk.Move(InPath: String; OutPath: String);
begin
 with Http.Request do
  begin
    Accept:='*/*';
    CustomHeaders.AddValue('Destination','/'+InPath);
  end;
  Http.Move(YaURL+OutPath);
end;

//========//

procedure TYaDisk.GetSpaceDisk(var Available: String; var Used: String);
var
  Answer:String;
  Stream:TStringList;
  Reg,Reg1:TRegex;
 begin
  Stream:=TStringList.Create;
  Stream.Add('<D:propfind xmlns:D="DAV:">');
  Stream.Add('  <D:prop>');
  Stream.Add('    <D:quota-available-bytes/>');
  Stream.Add('    <D:quota-used-bytes/>');
  Stream.Add('  </D:prop>');
  Stream.Add('</D:propfind>');
  with http.Request do
    begin
      Accept:=  '*/*';
      CustomHeaders.AddValue('Depth','0');
    end;
  Answer:=http.Prop(Id_HTTPMethodPropFind,YaURL,Stream);
  Reg:= TRegex.Create('[\d]{6,}');
  if reg.IsMatch(Answer) then
    Used:=reg.Matches(Answer).Item[0].Value;
    Available:=reg.Matches(Answer).Item[1].Value;
  FreeAndNil(Stream);
end;

procedure TYaDisk.Folder(FolderName: string;Depth:integer);
var
  Answer:AnsiString;
 begin
  with http.Request do
    begin
      Accept:=  '*/*';
      CustomHeaders.AddValue('Depth',IntToStr(Depth));
    end;
  Answer:=http.Prop(Id_HTTPMethodPropFind,YaURL,nil);
  showmessage(answer);
end;

procedure TYaDisk.GetProperties(ObjectName: string);
var
  Answer:String;
  Stream:TStringList;
 begin
  Stream:=TStringList.Create;
  Stream.Add('<?xml version="1.0" encoding="utf-8" ?>');
  Stream.Add('<propfind xmlns="DAV:">');
  Stream.Add('<prop>');
  Stream.Add('<myprop xmlns="mynamespace"/>');
  Stream.Add('</prop>');
  Stream.Add('</propfind>');
  with http.Request do
    begin
      Accept              := '*/*';
      CustomHeaders.AddValue('Depth','1');
      ContentLength       :=Length(stream.GetText);
      ContentType         :='application/x-www-form-urlencoded';
    end;
  Answer:=http.Prop(Id_HTTPMethodPropFind,YaURL+ObjectName,Stream);
  showmessage(answer);
  FreeAndNil(Stream);
end;

function TYaDisk.Share(FileName: string; Open: Boolean = True):String;
var
  Answer:String;
  Stream:TStringList;
 begin
  Stream:=TStringList.Create;
  Stream.Add('<propertyupdate xmlns="DAV:">');
  Stream.Add('<set>');
  Stream.Add('<prop>');
  Stream.Add('<public_url xmlns="urn:yandex:disk:meta">true</public_url>');
  Stream.Add('</prop>');
  Stream.Add('</set>');
  Stream.Add('</propertyupdate>');
  with http.Request do
    begin
      UserAgent             :=ApplicationName;
      ContentLength         :=Length(stream.GetText);
    end;
  Answer:=http.Prop(Id_HTTPMethodPropPatch,YaURL+FileName,Stream);
  Result:= Regex(Answer,'http://[a-z./0-9A-Z]+');
  FreeAndNil(Stream);
end;

function TYaDisk.IsShare(FileName: string):boolean;
var
  Answer,Res:String;
  Stream:TStringList;
 begin
  Stream:=TStringList.Create;
  Stream.Add('<propfind xmlns="DAV:">');
  Stream.Add('<prop>');
  Stream.Add('<public_url xmlns="urn:yandex:disk:meta"/>');
  Stream.Add('</prop>');
  Stream.Add('</propfind>');
  with http.Request do
    begin
      UserAgent             :=ApplicationName;
      CustomHeaders.AddValue('Depth','0');
      ContentLength         :=Length(stream.GetText);
    end;
  Answer:=http.Prop(Id_HTTPMethodPropFind,YaURL+FileName,Stream);
  Res:= Regex(Answer,'OK');
  if Res='' then
    result:=false
  else
    result:=true;
  FreeAndNil(Stream);
end;

{$ENDREGION}

procedure Register;
begin
  RegisterComponents('YaDisk', [TYaDisk]);
end;

end.
