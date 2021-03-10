module Testable = struct
  let fiat_error = Alcotest.testable Mirage_crypto_ec.pp_error ( = )

  let ok_or_error = Alcotest.result Alcotest.unit fiat_error
end

let key_pair_of_hex h =
  Mirage_crypto_ec.P256.Dh.gen_key ~rng:(fun _ -> Hex.to_cstruct h)

let scalar_of_hex h = fst (key_pair_of_hex h)

let pp_hex_le fmt cs =
  let n = Cstruct.len cs in
  for i = n - 1 downto 0 do
    let byte = Cstruct.get_uint8 cs i in
    Format.fprintf fmt "%02x" byte
  done

let pp_result ppf = function
  | Ok cs -> pp_hex_le ppf cs
  | Error e -> Format.fprintf ppf "%a" Mirage_crypto_ec.pp_error e

let key_exchange =
  let test ~name d p ~expected =
    ( name,
      `Quick,
      fun () ->
        Mirage_crypto_ec.P256.Dh.key_exchange d p
        |> Format.asprintf "%a" pp_result
        |> Alcotest.check Alcotest.string __LOC__ expected )
  in
  let d_a, p_a =
    key_pair_of_hex
      (`Hex "200102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
  in
  let d_b, p_b =
    key_pair_of_hex
      (`Hex "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
  in
  [
    test ~name:"b*A" d_b p_a
      ~expected:
        "2e3e4065a62a7f425aaf8aae3d158f367c733300b5002e0b62f4bc6260789e1b";
    test ~name:"a*B" d_a p_b
      ~expected:
        "2e3e4065a62a7f425aaf8aae3d158f367c733300b5002e0b62f4bc6260789e1b";
    test ~name:"a*A" d_a p_a
      ~expected:
        "2ea4e810837da217a5bfd05f01d12459eeda830b6e0dec7f8afa425c5b55c507";
    test ~name:"b*B" d_b p_b
      ~expected:
        "a7666bcc3818472194460f7df22d80a5886da0e1679eac930175ce1ff733c7ca";
  ]

let scalar_mult =
  let test ~n ~scalar ~point ~expected =
    let scalar = scalar_of_hex scalar in
    let point = Hex.to_cstruct point in
    ( Printf.sprintf "Scalar mult (#%d)" n,
      `Quick,
      fun () ->
        Mirage_crypto_ec.P256.Dh.key_exchange scalar point
        |> Format.asprintf "%a" pp_result
        |> Alcotest.check Alcotest.string __LOC__ expected )
  in
  let point =
    `Hex
      "046B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C2964FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5"
  in
  [
    test ~n:0
      ~scalar:
        (`Hex
          "0000000000000000000000000000000000000000000000000000000000000001")
      ~point
      ~expected:
        "96c298d84539a1f4a033eb2d817d0377f240a463e5e6bcf847422ce1f2d1176b";
    test ~n:1
      ~scalar:
        (`Hex
          "0000000000000000000000000000000000000000000000000000000000000002")
      ~point
      ~expected:
        "78996647fc480ba6351bf277e26989c0c31ab5040338528a7e4f038d187bf27c";
    test ~n:2
      ~scalar:
        (`Hex
          "0000000000000000000000000000000000000000000000000000000000000004")
      ~point
      ~expected:
        "5208036b44029350ef965578dbe21f03d02be69e65de2da0bb8fd032354a53e2";
    test ~n:3
      ~scalar:
        (`Hex
          "0612465c89a023ab17855b0a6bcebfd3febb53aef84138647b5352e02c10c346")
      ~point:
        (`Hex
          "0462d5bd3372af75fe85a040715d0f502428e07046868b0bfdfa61d731afe44f26ac333a93a9e70a81cd5a95b5bf8d13990eb741c8c38872b4a07d275a014e30cf")
      ~expected:
        "854271e19508bc935ab22b95cd2be13a0e78265f528b658b3219028b900d0253";
    test ~n:4
      ~scalar:
        (`Hex
          "0a0d622a47e48f6bc1038ace438c6f528aa00ad2bd1da5f13ee46bf5f633d71a")
      ~point:
        (`Hex
          "043cbc1b31b43f17dc200dd70c2944c04c6cb1b082820c234a300b05b7763844c74fde0a4ef93887469793270eb2ff148287da9265b0334f9e2609aac16e8ad503")
      ~expected:
        "ffffffffffffffffffffffffffffffff3022cfeeffffffffffffffffffffff7f";
    test ~n:5
      ~scalar:
        (`Hex
          "55d55f11bb8da1ea318bca7266f0376662441ea87270aa2077f1b770c4854a48")
      ~point:
        (`Hex
          "04000000000000000000000000000000000000000000000000000000000000000066485c780e2f83d72433bd5d84a06bb6541c2af31dae871728bf856a174f93f4")
      ~expected:
        "48e82c9b82c88cb9fc2a5cff9e7c41bc4255ff6bd3814538c9b130877c07e4cf";
  ]

let to_ok_or_error = function Ok _ -> Ok () | Error _ as e -> e

let point_validation =
  let test ~name ~x ~y ~expected =
    let scalar =
      scalar_of_hex
        (`Hex
          "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
    in
    let point =
      Cstruct.concat [ Cstruct.of_hex "04"; Hex.to_cstruct x; Hex.to_cstruct y ]
    in
    ( name,
      `Quick,
      fun () ->
        Mirage_crypto_ec.P256.Dh.key_exchange scalar point
        |> to_ok_or_error
        |> Alcotest.check Testable.ok_or_error __LOC__ expected )
  in
  let zero = `Hex (String.make 64 '0') in
  let sb =
    `Hex "66485c780e2f83d72433bd5d84a06bb6541c2af31dae871728bf856a174f93f4"
  in
  [
    test ~name:"Ok"
      ~x:
        (`Hex
          "62d5bd3372af75fe85a040715d0f502428e07046868b0bfdfa61d731afe44f26")
      ~y:
        (`Hex
          "ac333a93a9e70a81cd5a95b5bf8d13990eb741c8c38872b4a07d275a014e30cf")
      ~expected:(Ok ());
    test ~name:"P=0"
      ~x:
        (`Hex
          "0000000000000000000000000000000000000000000000000000000000000000")
      ~y:
        (`Hex
          "0000000000000000000000000000000000000000000000000000000000000000")
      ~expected:(Error `Not_on_curve);
    test ~name:"(0, sqrt(b))" ~x:zero ~y:sb ~expected:(Ok ());
    test ~name:"out of range"
      ~x:
        (`Hex
          "FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF")
      ~y:sb
      ~expected:(Error `Invalid_range);
  ]

let scalar_validation =
  let test_scalar_validation ~name ~scalar ~expected =
    let safe =
      Cstruct.of_hex
        "0000000000000000000000000000000000000000000000000000000000000001"
    in
    let ncalls = ref 0 in
    let return_value = ref (Some (Hex.to_cstruct scalar)) in
    let rng _ =
      incr ncalls;
      match !return_value with
      | None -> safe
      | Some rv ->
          return_value := None;
          rv
    in
    ( name,
      `Quick,
      fun () ->
        let _, _ = Mirage_crypto_ec.P256.Dh.gen_key ~rng in
        let got = !ncalls in
        Alcotest.check Alcotest.int __LOC__ expected got )
  in
  [
    test_scalar_validation ~name:"0"
      ~scalar:
        (`Hex
          "0000000000000000000000000000000000000000000000000000000000000000")
      ~expected:2;
    test_scalar_validation ~name:"1"
      ~scalar:
        (`Hex
          "0000000000000000000000000000000000000000000000000000000000000001")
      ~expected:1;
    test_scalar_validation ~name:"n-1"
      ~scalar:
        (`Hex
          "FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632550")
      ~expected:1;
    test_scalar_validation ~name:"n"
      ~scalar:
        (`Hex
          "FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551")
      ~expected:2;
  ]

let ecdsa_gen () =
  let d = Cstruct.of_hex "C477F9F6 5C22CCE2 0657FAA5 B2D1D812 2336F851 A508A1ED 04E479C3 4985BF96" in
  let p = match
      Mirage_crypto_ec.P256.Dsa.pub_of_cstruct
        (Cstruct.of_hex {|04
                        B7E08AFD FE94BAD3 F1DC8C73 4798BA1C 62B3A0AD 1E9EA2A3 8201CD08 89BC7A19
                        3603F747 959DBF7A 4BB226E4 19287290 63ADC7AE 43529E61 B563BBC6 06CC5E09|})
    with
    | Ok a -> a
    | Error _ -> assert false
  in
  let _priv, pub = Mirage_crypto_ec.P256.Dsa.generate ~rng:(fun _ -> d) in
  let pub_eq a b =
    Cstruct.equal
      (Mirage_crypto_ec.P256.Dsa.pub_to_cstruct a)
      (Mirage_crypto_ec.P256.Dsa.pub_to_cstruct b)
  in
  Alcotest.(check bool __LOC__ true (pub_eq pub p))

let ecdsa_sign () =
  let d = Cstruct.of_hex "C477F9F6 5C22CCE2 0657FAA5 B2D1D812 2336F851 A508A1ED 04E479C3 4985BF96"
  and k = Cstruct.of_hex "7A1A7E52 797FC8CA AA435D2A 4DACE391 58504BF2 04FBE19F 14DBB427 FAEE50AE"
  and e = Cstruct.of_hex "A41A41A1 2A799548 211C410C 65D8133A FDE34D28 BDD542E4 B680CF28 99C8A8C4"
  in
  let r = Cstruct.of_hex "2B42F576 D07F4165 FF65D1F3 B1500F81 E44C316F 1F0B3EF5 7325B69A CA46104F"
  and s = Cstruct.of_hex "DC42C212 2D6392CD 3E3A993A 89502A81 98C1886F E69D262C 4B329BDB 6B63FAF1"
  in
  let key, _pub = Mirage_crypto_ec.P256.Dsa.generate ~rng:(fun _ -> d) in
  let (r', s') = Mirage_crypto_ec.P256.Dsa.sign ~key ~k e in
  Alcotest.(check bool __LOC__ true (Cstruct.equal r r' && Cstruct.equal s s'))

let ecdsa_verify () =
  let key =
    match Mirage_crypto_ec.P256.Dsa.pub_of_cstruct
            (Cstruct.of_hex {|04
                        B7E08AFD FE94BAD3 F1DC8C73 4798BA1C 62B3A0AD 1E9EA2A3 8201CD08 89BC7A19
                        3603F747 959DBF7A 4BB226E4 19287290 63ADC7AE 43529E61 B563BBC6 06CC5E09|})
    with
    | Ok a -> a
    | Error _ -> assert false
  and e = Cstruct.of_hex "A41A41A1 2A799548 211C410C 65D8133A FDE34D28 BDD542E4 B680CF28 99C8A8C4"
  and r = Cstruct.of_hex "2B42F576 D07F4165 FF65D1F3 B1500F81 E44C316F 1F0B3EF5 7325B69A CA46104F"
  and s = Cstruct.of_hex "DC42C212 2D6392CD 3E3A993A 89502A81 98C1886F E69D262C 4B329BDB 6B63FAF1"
  in
  Alcotest.(check bool __LOC__ true (Mirage_crypto_ec.P256.Dsa.verify ~key (r, s) e))

let ecdsa = [
  (* from https://csrc.nist.rip/groups/ST/toolkit/documents/Examples/ECDSA_Prime.pdf *)
  "ECDSA gen", `Quick, ecdsa_gen ;
  "ECDSA sign", `Quick, ecdsa_sign ;
  "ECDSA verify", `Quick, ecdsa_verify ;
]

let ecdsa_rfc6979_p224 =
  (* A.2.4 - P 224 *)
  let priv, pub =
    let data = Cstruct.of_hex "F220266E1105BFE3083E03EC7A3A654651F45E37167E88600BF257C1" in
    Mirage_crypto_ec.P224.Dsa.generate ~rng:(fun _ -> data)
  in
  let pub_rfc () =
    let fst = Cstruct.create 1 in
    Cstruct.set_uint8 fst 0 4;
    let ux = Cstruct.of_hex "00CF08DA5AD719E42707FA431292DEA11244D64FC51610D94B130D6C"
    and uy = Cstruct.of_hex "EEAB6F3DEBE455E3DBF85416F7030CBD94F34F2D6F232C69F3C1385A"
    in
    match Mirage_crypto_ec.P224.Dsa.pub_of_cstruct (Cstruct.concat [ fst ; ux ; uy ]) with
    | Ok p ->
      let pub_eq =
        Cstruct.equal
          (Mirage_crypto_ec.P224.Dsa.pub_to_cstruct pub)
          (Mirage_crypto_ec.P224.Dsa.pub_to_cstruct p)
      in
      Alcotest.(check bool __LOC__ true pub_eq)
    | Error _ -> Alcotest.fail "bad public key"
  in
  let case hash ~message ~k ~r ~s () =
    let msg =
      let h = Mirage_crypto.Hash.digest hash (Cstruct.of_string message) in
      Cstruct.sub h 0 (min (Cstruct.len h) 28)
    and k = Cstruct.of_hex k
    in
    let k' =
      let module H = (val (Mirage_crypto.Hash.module_of hash)) in
      let module K = Mirage_crypto_ec.P224.Dsa.K_gen (H) in
      K.generate ~key:priv msg
    in
    Alcotest.(check bool __LOC__ true (Cstruct.equal k k'));
    let sig_eq (r', s') =
      Cstruct.equal (Cstruct.of_hex r) r' && Cstruct.equal (Cstruct.of_hex s) s'
    in
    let sig' = Mirage_crypto_ec.P224.Dsa.sign ~key:priv ~k msg in
    Alcotest.(check bool __LOC__ true (sig_eq sig'))
  in
  let cases = [

   case `SHA1 ~message:"sample"
   ~k:"7EEFADD91110D8DE6C2C470831387C50D3357F7F4D477054B8B426BC"
   ~r:"22226F9D40A96E19C4A301CE5B74B115303C0F3A4FD30FC257FB57AC"
   ~s:"66D1CDD83E3AF75605DD6E2FEFF196D30AA7ED7A2EDF7AF475403D69";

   case `SHA224 ~message:"sample"
   ~k:"C1D1F2F10881088301880506805FEB4825FE09ACB6816C36991AA06D"
   ~r:"1CDFE6662DDE1E4A1EC4CDEDF6A1F5A2FB7FBD9145C12113E6ABFD3E"
   ~s:"A6694FD7718A21053F225D3F46197CA699D45006C06F871808F43EBC";

   case `SHA256 ~message:"sample"
   ~k:"AD3029E0278F80643DE33917CE6908C70A8FF50A411F06E41DEDFCDC"
   ~r:"61AA3DA010E8E8406C656BC477A7A7189895E7E840CDFE8FF42307BA"
   ~s:"BC814050DAB5D23770879494F9E0A680DC1AF7161991BDE692B10101";

   case `SHA384 ~message:"sample"
   ~k:"52B40F5A9D3D13040F494E83D3906C6079F29981035C7BD51E5CAC40"
   ~r:"0B115E5E36F0F9EC81F1325A5952878D745E19D7BB3EABFABA77E953"
   ~s:"830F34CCDFE826CCFDC81EB4129772E20E122348A2BBD889A1B1AF1D";

   case `SHA512 ~message:"sample"
   ~k:"9DB103FFEDEDF9CFDBA05184F925400C1653B8501BAB89CEA0FBEC14"
   ~r:"074BD1D979D5F32BF958DDC61E4FB4872ADCAFEB2256497CDAC30397"
   ~s:"A4CECA196C3D5A1FF31027B33185DC8EE43F288B21AB342E5D8EB084";

   case `SHA1 ~message:"test"
   ~k:"2519178F82C3F0E4F87ED5883A4E114E5B7A6E374043D8EFD329C253"
   ~r:"DEAA646EC2AF2EA8AD53ED66B2E2DDAA49A12EFD8356561451F3E21C"
   ~s:"95987796F6CF2062AB8135271DE56AE55366C045F6D9593F53787BD2";

   case `SHA224 ~message:"test"
   ~k:"DF8B38D40DCA3E077D0AC520BF56B6D565134D9B5F2EAE0D34900524"
   ~r:"C441CE8E261DED634E4CF84910E4C5D1D22C5CF3B732BB204DBEF019"
   ~s:"902F42847A63BDC5F6046ADA114953120F99442D76510150F372A3F4";

   case `SHA256 ~message:"test"
   ~k:"FF86F57924DA248D6E44E8154EB69F0AE2AEBAEE9931D0B5A969F904"
   ~r:"AD04DDE87B84747A243A631EA47A1BA6D1FAA059149AD2440DE6FBA6"
   ~s:"178D49B1AE90E3D8B629BE3DB5683915F4E8C99FDF6E666CF37ADCFD";

   case `SHA384 ~message:"test"
   ~k:"7046742B839478C1B5BD31DB2E862AD868E1A45C863585B5F22BDC2D"
   ~r:"389B92682E399B26518A95506B52C03BC9379A9DADF3391A21FB0EA4"
   ~s:"414A718ED3249FF6DBC5B50C27F71F01F070944DA22AB1F78F559AAB";

   case `SHA512 ~message:"test"
   ~k:"E39C2AA4EA6BE2306C72126D40ED77BF9739BB4D6EF2BBB1DCB6169D"
   ~r:"049F050477C5ADD858CAC56208394B5A55BAEBBE887FDF765047C17C"
   ~s:"077EB13E7005929CEFA3CD0403C7CDCC077ADF4E44F3C41B2F60ECFF";

  ] in
  ("public key matches", `Quick, pub_rfc) ::
  List.mapi (fun i c -> "RFC 6979 A.2.4 " ^ string_of_int i, `Quick, c) cases

let ecdsa_rfc6979_p256 =
  (* A.2.5 - P 256 *)
  let priv, pub =
    let data = Cstruct.of_hex "C9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721" in
    Mirage_crypto_ec.P256.Dsa.generate ~rng:(fun _ -> data)
  in
  let pub_rfc () =
    let fst = Cstruct.create 1 in
    Cstruct.set_uint8 fst 0 4;
    let ux = Cstruct.of_hex "60FED4BA255A9D31C961EB74C6356D68C049B8923B61FA6CE669622E60F29FB6"
    and uy = Cstruct.of_hex "7903FE1008B8BC99A41AE9E95628BC64F2F1B20C2D7E9F5177A3C294D4462299"
    in
    match Mirage_crypto_ec.P256.Dsa.pub_of_cstruct (Cstruct.concat [ fst ; ux ; uy ]) with
    | Ok p ->
      let pub_eq =
        Cstruct.equal
          (Mirage_crypto_ec.P256.Dsa.pub_to_cstruct pub)
          (Mirage_crypto_ec.P256.Dsa.pub_to_cstruct p)
      in
      Alcotest.(check bool __LOC__ true pub_eq)
    | Error _ -> Alcotest.fail "bad public key"
  in
  let case hash ~message ~k ~r ~s () =
    let msg =
      let h = Mirage_crypto.Hash.digest hash (Cstruct.of_string message) in
      Cstruct.sub h 0 (min (Cstruct.len h) 32)
    and k = Cstruct.of_hex k
    in
    let k' =
      let module H = (val (Mirage_crypto.Hash.module_of hash)) in
      let module K = Mirage_crypto_ec.P256.Dsa.K_gen (H) in
      K.generate ~key:priv msg
    in
    Alcotest.(check bool __LOC__ true (Cstruct.equal k k'));
    let sig_eq (r', s') =
      Cstruct.equal (Cstruct.of_hex r) r' && Cstruct.equal (Cstruct.of_hex s) s'
    in
    let sig' = Mirage_crypto_ec.P256.Dsa.sign ~key:priv ~k msg in
    Alcotest.(check bool __LOC__ true (sig_eq sig'))
  in
  let cases = [
    case `SHA1  ~message:"sample"
      ~k:"882905F1227FD620FBF2ABF21244F0BA83D0DC3A9103DBBEE43A1FB858109DB4"
      ~r:"61340C88C3AAEBEB4F6D667F672CA9759A6CCAA9FA8811313039EE4A35471D32"
      ~s:"6D7F147DAC089441BB2E2FE8F7A3FA264B9C475098FDCF6E00D7C996E1B8B7EB" ;
    case `SHA224 ~message:"sample"
      ~k:"103F90EE9DC52E5E7FB5132B7033C63066D194321491862059967C715985D473"
      ~r:"53B2FFF5D1752B2C689DF257C04C40A587FABABB3F6FC2702F1343AF7CA9AA3F"
      ~s:"B9AFB64FDC03DC1A131C7D2386D11E349F070AA432A4ACC918BEA988BF75C74C" ;
    case `SHA256 ~message:"sample"
      ~k:"A6E3C57DD01ABE90086538398355DD4C3B17AA873382B0F24D6129493D8AAD60"
      ~r:"EFD48B2AACB6A8FD1140DD9CD45E81D69D2C877B56AAF991C34D0EA84EAF3716"
      ~s:"F7CB1C942D657C41D436C7A1B6E29F65F3E900DBB9AFF4064DC4AB2F843ACDA8" ;
    case `SHA384 ~message:"sample"
      ~k:"09F634B188CEFD98E7EC88B1AA9852D734D0BC272F7D2A47DECC6EBEB375AAD4"
      ~r:"0EAFEA039B20E9B42309FB1D89E213057CBF973DC0CFC8F129EDDDC800EF7719"
      ~s:"4861F0491E6998B9455193E34E7B0D284DDD7149A74B95B9261F13ABDE940954" ;
    case `SHA512 ~message:"sample"
      ~k:"5FA81C63109BADB88C1F367B47DA606DA28CAD69AA22C4FE6AD7DF73A7173AA5"
      ~r:"8496A60B5E9B47C825488827E0495B0E3FA109EC4568FD3F8D1097678EB97F00"
      ~s:"2362AB1ADBE2B8ADF9CB9EDAB740EA6049C028114F2460F96554F61FAE3302FE" ;
    case `SHA1 ~message:"test"
      ~k:"8C9520267C55D6B980DF741E56B4ADEE114D84FBFA2E62137954164028632A2E"
      ~r:"0CBCC86FD6ABD1D99E703E1EC50069EE5C0B4BA4B9AC60E409E8EC5910D81A89"
      ~s:"01B9D7B73DFAA60D5651EC4591A0136F87653E0FD780C3B1BC872FFDEAE479B1" ;
    case `SHA224 ~message:"test"
      ~k:"669F4426F2688B8BE0DB3A6BD1989BDAEFFF84B649EEB84F3DD26080F667FAA7"
      ~r:"C37EDB6F0AE79D47C3C27E962FA269BB4F441770357E114EE511F662EC34A692"
      ~s:"C820053A05791E521FCAAD6042D40AEA1D6B1A540138558F47D0719800E18F2D" ;
    case `SHA256 ~message:"test"
      ~k:"D16B6AE827F17175E040871A1C7EC3500192C4C92677336EC2537ACAEE0008E0"
      ~r:"F1ABB023518351CD71D881567B1EA663ED3EFCF6C5132B354F28D3B0B7D38367"
      ~s:"019F4113742A2B14BD25926B49C649155F267E60D3814B4C0CC84250E46F0083" ;
    case `SHA384 ~message:"test"
      ~k:"16AEFFA357260B04B1DD199693960740066C1A8F3E8EDD79070AA914D361B3B8"
      ~r:"83910E8B48BB0C74244EBDF7F07A1C5413D61472BD941EF3920E623FBCCEBEB6"
      ~s:"8DDBEC54CF8CD5874883841D712142A56A8D0F218F5003CB0296B6B509619F2C" ;
    case `SHA512 ~message:"test"
      ~k:"6915D11632ACA3C40D5D51C08DAF9C555933819548784480E93499000D9F0B7F"
      ~r:"461D93F31B6540894788FD206C07CFA0CC35F46FA3C91816FFF1040AD1581A04"
      ~s:"39AF9F15DE0DB8D97E72719C74820D304CE5226E32DEDAE67519E840D1194E55" ;
  ] in
  ("public key matches", `Quick, pub_rfc) ::
  List.mapi (fun i c -> "RFC 6979 A.2.5 " ^ string_of_int i, `Quick, c) cases

let ecdsa_rfc6979_p384 =
  (* A.2.6 - P 384 *)
  let priv, pub =
    let data = Cstruct.of_hex "6B9D3DAD2E1B8C1C05B19875B6659F4DE23C3B667BF297BA9AA47740787137D896D5724E4C70A825F872C9EA60D2EDF5" in
    Mirage_crypto_ec.P384.Dsa.generate ~rng:(fun _ -> data)
  in
  let pub_rfc () =
    let fst = Cstruct.create 1 in
    Cstruct.set_uint8 fst 0 4;
    let ux = Cstruct.of_hex "EC3A4E415B4E19A4568618029F427FA5DA9A8BC4AE92E02E06AAE5286B300C64DEF8F0EA9055866064A254515480BC13"
    and uy = Cstruct.of_hex "8015D9B72D7D57244EA8EF9AC0C621896708A59367F9DFB9F54CA84B3F1C9DB1288B231C3AE0D4FE7344FD2533264720"
    in
    match Mirage_crypto_ec.P384.Dsa.pub_of_cstruct (Cstruct.concat [ fst ; ux ; uy ]) with
    | Ok p ->
      let pub_eq =
        Cstruct.equal
          (Mirage_crypto_ec.P384.Dsa.pub_to_cstruct pub)
          (Mirage_crypto_ec.P384.Dsa.pub_to_cstruct p)
      in
      Alcotest.(check bool __LOC__ true pub_eq)
    | Error _ -> Alcotest.fail "bad public key"
  in
  let case hash ~message ~k ~r ~s () =
    let msg =
      let h = Mirage_crypto.Hash.digest hash (Cstruct.of_string message) in
      Cstruct.sub h 0 (min (Cstruct.len h) 48)
    and k = Cstruct.of_hex k
    in
    let k' =
      let module H = (val (Mirage_crypto.Hash.module_of hash)) in
      let module K = Mirage_crypto_ec.P384.Dsa.K_gen (H) in
      K.generate ~key:priv msg
    in
    Alcotest.(check bool __LOC__ true (Cstruct.equal k k'));
    let sig_eq (r', s') =
      Cstruct.equal (Cstruct.of_hex r) r' && Cstruct.equal (Cstruct.of_hex s) s'
    in
    let sig' = Mirage_crypto_ec.P384.Dsa.sign ~key:priv ~k msg in
    Alcotest.(check bool __LOC__ true (sig_eq sig'))
  in
  let cases = [
   case `SHA1 ~message:"sample"
   ~k:"4471EF7518BB2C7C20F62EAE1C387AD0C5E8E470995DB4ACF694466E6AB09663
       0F29E5938D25106C3C340045A2DB01A7"
   ~r:"EC748D839243D6FBEF4FC5C4859A7DFFD7F3ABDDF72014540C16D73309834FA3
       7B9BA002899F6FDA3A4A9386790D4EB2"
   ~s:"A3BCFA947BEEF4732BF247AC17F71676CB31A847B9FF0CBC9C9ED4C1A5B3FACF
       26F49CA031D4857570CCB5CA4424A443";

   case `SHA224 ~message:"sample"
   ~k:"A4E4D2F0E729EB786B31FC20AD5D849E304450E0AE8E3E341134A5C1AFA03CAB
       8083EE4E3C45B06A5899EA56C51B5879"
   ~r:"42356E76B55A6D9B4631C865445DBE54E056D3B3431766D0509244793C3F9366
       450F76EE3DE43F5A125333A6BE060122"
   ~s:"9DA0C81787064021E78DF658F2FBB0B042BF304665DB721F077A4298B095E483
       4C082C03D83028EFBF93A3C23940CA8D";

   case `SHA256 ~message:"sample"
   ~k:"180AE9F9AEC5438A44BC159A1FCB277C7BE54FA20E7CF404B490650A8ACC414E
       375572342863C899F9F2EDF9747A9B60"
   ~r:"21B13D1E013C7FA1392D03C5F99AF8B30C570C6F98D4EA8E354B63A21D3DAA33
       BDE1E888E63355D92FA2B3C36D8FB2CD"
   ~s:"F3AA443FB107745BF4BD77CB3891674632068A10CA67E3D45DB2266FA7D1FEEB
       EFDC63ECCD1AC42EC0CB8668A4FA0AB0";

   case `SHA384 ~message:"sample"
   ~k:"94ED910D1A099DAD3254E9242AE85ABDE4BA15168EAF0CA87A555FD56D10FBCA
       2907E3E83BA95368623B8C4686915CF9"
   ~r:"94EDBB92A5ECB8AAD4736E56C691916B3F88140666CE9FA73D64C4EA95AD133C
       81A648152E44ACF96E36DD1E80FABE46"
   ~s:"99EF4AEB15F178CEA1FE40DB2603138F130E740A19624526203B6351D0A3A94F
       A329C145786E679E7B82C71A38628AC8";

   case `SHA512 ~message:"sample"
   ~k:"92FC3C7183A883E24216D1141F1A8976C5B0DD797DFA597E3D7B32198BD35331
       A4E966532593A52980D0E3AAA5E10EC3"
   ~r:"ED0959D5880AB2D869AE7F6C2915C6D60F96507F9CB3E047C0046861DA4A799C
       FE30F35CC900056D7C99CD7882433709"
   ~s:"512C8CCEEE3890A84058CE1E22DBC2198F42323CE8ACA9135329F03C068E5112
       DC7CC3EF3446DEFCEB01A45C2667FDD5";

   case `SHA1 ~message:"test"
   ~k:"66CC2C8F4D303FC962E5FF6A27BD79F84EC812DDAE58CF5243B64A4AD8094D47
       EC3727F3A3C186C15054492E30698497"
   ~r:"4BC35D3A50EF4E30576F58CD96CE6BF638025EE624004A1F7789A8B8E43D0678
       ACD9D29876DAF46638645F7F404B11C7"
   ~s:"D5A6326C494ED3FF614703878961C0FDE7B2C278F9A65FD8C4B7186201A29916
       95BA1C84541327E966FA7B50F7382282";

   case `SHA224 ~message:"test"
   ~k:"18FA39DB95AA5F561F30FA3591DC59C0FA3653A80DAFFA0B48D1A4C6DFCBFF6E
       3D33BE4DC5EB8886A8ECD093F2935726"
   ~r:"E8C9D0B6EA72A0E7837FEA1D14A1A9557F29FAA45D3E7EE888FC5BF954B5E624
       64A9A817C47FF78B8C11066B24080E72"
   ~s:"07041D4A7A0379AC7232FF72E6F77B6DDB8F09B16CCE0EC3286B2BD43FA8C614
       1C53EA5ABEF0D8231077A04540A96B66";

   case `SHA256 ~message:"test"
   ~k:"0CFAC37587532347DC3389FDC98286BBA8C73807285B184C83E62E26C401C0FA
       A48DD070BA79921A3457ABFF2D630AD7"
   ~r:"6D6DEFAC9AB64DABAFE36C6BF510352A4CC27001263638E5B16D9BB51D451559
       F918EEDAF2293BE5B475CC8F0188636B"
   ~s:"2D46F3BECBCC523D5F1A1256BF0C9B024D879BA9E838144C8BA6BAEB4B53B47D
       51AB373F9845C0514EEFB14024787265";

   case `SHA384 ~message:"test"
   ~k:"015EE46A5BF88773ED9123A5AB0807962D193719503C527B031B4C2D225092AD
       A71F4A459BC0DA98ADB95837DB8312EA"
   ~r:"8203B63D3C853E8D77227FB377BCF7B7B772E97892A80F36AB775D509D7A5FEB
       0542A7F0812998DA8F1DD3CA3CF023DB"
   ~s:"DDD0760448D42D8A43AF45AF836FCE4DE8BE06B485E9B61B827C2F13173923E0
       6A739F040649A667BF3B828246BAA5A5";

   case `SHA512 ~message:"test"
   ~k:"3780C4F67CB15518B6ACAE34C9F83568D2E12E47DEAB6C50A4E4EE5319D1E8CE
       0E2CC8A136036DC4B9C00E6888F66B6C"
   ~r:"A0D5D090C9980FAF3C2CE57B7AE951D31977DD11C775D314AF55F76C676447D0
       6FB6495CD21B4B6E340FC236584FB277"
   ~s:"976984E59B4C77B0E8E4460DCA3D9F20E07B9BB1F63BEEFAF576F6B2E8B22463
       4A2092CD3792E0159AD9CEE37659C736"
  ] in
  ("public key matches", `Quick, pub_rfc) ::
  List.mapi (fun i c -> "RFC 6979 A.2.6 " ^ string_of_int i, `Quick, c) cases

let ecdsa_rfc6979_p521 =
  (* A.2.7 - P 521 *)
  let of_h b = Cstruct.of_hex ((String.make 1 '0') ^ b) in
  let priv, pub =
    let data = of_h
        "0FAD06DAA62BA3B25D2FB40133DA757205DE67F5BB0018FEE8C86E1B68C7E75C
         AA896EB32F1F47C70855836A6D16FCC1466F6D8FBEC67DB89EC0C08B0E996B83
         538"
    in
    Mirage_crypto_ec.P521.Dsa.generate ~rng:(fun _ -> data)
  in
  let pub_rfc () =
    let fst = Cstruct.create 1 in
    Cstruct.set_uint8 fst 0 4;
    let ux = of_h
        "1894550D0785932E00EAA23B694F213F8C3121F86DC97A04E5A7167DB4E5BCD3
         71123D46E45DB6B5D5370A7F20FB633155D38FFA16D2BD761DCAC474B9A2F502
         3A4"
    and uy = of_h
        "0493101C962CD4D2FDDF782285E64584139C2F91B47F87FF82354D6630F746A2
         8A0DB25741B5B34A828008B22ACC23F924FAAFBD4D33F81EA66956DFEAA2BFDF
         CF5"
    in
    match Mirage_crypto_ec.P521.Dsa.pub_of_cstruct (Cstruct.concat [ fst ; ux ; uy ]) with
    | Ok p ->
      let pub_eq =
        Cstruct.equal
          (Mirage_crypto_ec.P521.Dsa.pub_to_cstruct pub)
          (Mirage_crypto_ec.P521.Dsa.pub_to_cstruct p)
      in
      Alcotest.(check bool __LOC__ true pub_eq)
    | Error _ -> Alcotest.fail "bad public key"
  in
  let case hash ~message ~k ~r ~s () =
    let msg = Mirage_crypto.Hash.digest hash (Cstruct.of_string message)
    and k = of_h k
    in
    let k' =
      let module H = (val (Mirage_crypto.Hash.module_of hash)) in
      let module K = Mirage_crypto_ec.P521.Dsa.K_gen (H) in
      K.generate ~key:priv msg
    in
    Alcotest.(check bool __LOC__ true (Cstruct.equal k k'));
    let sig_eq (r', s') =
      Cstruct.equal (of_h r) r' && Cstruct.equal (of_h s) s'
    in
    let sig' = Mirage_crypto_ec.P521.Dsa.sign ~key:priv ~k msg in
    Alcotest.(check bool __LOC__ true (sig_eq sig'))
  in
  let _cases = [

   case `SHA1 ~message:"sample"
   ~k:"089C071B419E1C2820962321787258469511958E80582E95D8378E0C2CCDB3CB
       42BEDE42F50E3FA3C71F5A76724281D31D9C89F0F91FC1BE4918DB1C03A5838D
       0F9"
   ~r:"0343B6EC45728975EA5CBA6659BBB6062A5FF89EEA58BE3C80B619F322C87910
       FE092F7D45BB0F8EEE01ED3F20BABEC079D202AE677B243AB40B5431D497C55D
       75D"
   ~s:"0E7B0E675A9B24413D448B8CC119D2BF7B2D2DF032741C096634D6D65D0DBE3D
       5694625FB9E8104D3B842C1B0E2D0B98BEA19341E8676AEF66AE4EBA3D5475D5
       D16";

   case `SHA224 ~message:"sample"
   ~k:"121415EC2CD7726330A61F7F3FA5DE14BE9436019C4DB8CB4041F3B54CF31BE0
       493EE3F427FB906393D895A19C9523F3A1D54BB8702BD4AA9C99DAB2597B9211
       3F3"
   ~r:"1776331CFCDF927D666E032E00CF776187BC9FDD8E69D0DABB4109FFE1B5E2A3
       0715F4CC923A4A5E94D2503E9ACFED92857B7F31D7152E0F8C00C15FF3D87E2E
       D2E"
   ~s:"050CB5265417FE2320BBB5A122B8E1A32BD699089851128E360E620A30C7E17B
       A41A666AF126CE100E5799B153B60528D5300D08489CA9178FB610A2006C254B
       41F";

   case `SHA256 ~message:"sample"
   ~k:"0EDF38AFCAAECAB4383358B34D67C9F2216C8382AAEA44A3DAD5FDC9C3257576
       1793FEF24EB0FC276DFC4F6E3EC476752F043CF01415387470BCBD8678ED2C7E
       1A0"
   ~r:"1511BB4D675114FE266FC4372B87682BAECC01D3CC62CF2303C92B3526012659
       D16876E25C7C1E57648F23B73564D67F61C6F14D527D54972810421E7D87589E
       1A7"
   ~s:"04A171143A83163D6DF460AAF61522695F207A58B95C0644D87E52AA1A347916
       E4F7A72930B1BC06DBE22CE3F58264AFD23704CBB63B29B931F7DE6C9D949A7E
       CFC";

   case `SHA384 ~message:"sample"
   ~k:"1546A108BC23A15D6F21872F7DED661FA8431DDBD922D0DCDB77CC878C8553FF
       AD064C95A920A750AC9137E527390D2D92F153E66196966EA554D9ADFCB109C4
       211"
   ~r:"1EA842A0E17D2DE4F92C15315C63DDF72685C18195C2BB95E572B9C5136CA4B4
       B576AD712A52BE9730627D16054BA40CC0B8D3FF035B12AE75168397F5D50C67
       451"
   ~s:"1F21A3CEE066E1961025FB048BD5FE2B7924D0CD797BABE0A83B66F1E35EEAF5
       FDE143FA85DC394A7DEE766523393784484BDF3E00114A1C857CDE1AA203DB65
       D61";

   case `SHA512 ~message:"sample"
   ~k:"1DAE2EA071F8110DC26882D4D5EAE0621A3256FC8847FB9022E2B7D28E6F1019
       8B1574FDD03A9053C08A1854A168AA5A57470EC97DD5CE090124EF52A2F7ECBF
       FD3"
   ~r:"0C328FAFCBD79DD77850370C46325D987CB525569FB63C5D3BC53950E6D4C5F1
       74E25A1EE9017B5D450606ADD152B534931D7D4E8455CC91F9B15BF05EC36E37
       7FA"
   ~s:"0617CCE7CF5064806C467F678D3B4080D6F1CC50AF26CA209417308281B68AF2
       82623EAA63E5B5C0723D8B8C37FF0777B1A20F8CCB1DCCC43997F1EE0E44DA4A
       67A";

   case `SHA1 ~message:"test"
   ~k:"0BB9F2BF4FE1038CCF4DABD7139A56F6FD8BB1386561BD3C6A4FC818B20DF5DD
       BA80795A947107A1AB9D12DAA615B1ADE4F7A9DC05E8E6311150F47F5C57CE8B
       222"
   ~r:"13BAD9F29ABE20DE37EBEB823C252CA0F63361284015A3BF430A46AAA80B87B0
       693F0694BD88AFE4E661FC33B094CD3B7963BED5A727ED8BD6A3A202ABE009D0
       367"
   ~s:"1E9BB81FF7944CA409AD138DBBEE228E1AFCC0C890FC78EC8604639CB0DBDC90
       F717A99EAD9D272855D00162EE9527567DD6A92CBD629805C0445282BBC91679
       7FF";

   case `SHA224 ~message:"test"
   ~k:"040D09FCF3C8A5F62CF4FB223CBBB2B9937F6B0577C27020A99602C25A011369
       87E452988781484EDBBCF1C47E554E7FC901BC3085E5206D9F619CFF07E73D6F
       706"
   ~r:"1C7ED902E123E6815546065A2C4AF977B22AA8EADDB68B2C1110E7EA44D42086
       BFE4A34B67DDC0E17E96536E358219B23A706C6A6E16BA77B65E1C595D43CAE1
       7FB"
   ~s:"177336676304FCB343CE028B38E7B4FBA76C1C1B277DA18CAD2A8478B2A9A9F5
       BEC0F3BA04F35DB3E4263569EC6AADE8C92746E4C82F8299AE1B8F1739F8FD51
       9A4";

   case `SHA256 ~message:"test"
   ~k:"01DE74955EFAABC4C4F17F8E84D881D1310B5392D7700275F82F145C61E84384
       1AF09035BF7A6210F5A431A6A9E81C9323354A9E69135D44EBD2FCAA7731B909
       258"
   ~r:"00E871C4A14F993C6C7369501900C4BC1E9C7B0B4BA44E04868B30B41D807104
       2EB28C4C250411D0CE08CD197E4188EA4876F279F90B3D8D74A3C76E6F1E4656
       AA8"
   ~s:"0CD52DBAA33B063C3A6CD8058A1FB0A46A4754B034FCC644766CA14DA8CA5CA9
       FDE00E88C1AD60CCBA759025299079D7A427EC3CC5B619BFBC828E7769BCD694
       E86";

   case `SHA384 ~message:"test"
   ~k:"1F1FC4A349A7DA9A9E116BFDD055DC08E78252FF8E23AC276AC88B1770AE0B5D
       CEB1ED14A4916B769A523CE1E90BA22846AF11DF8B300C38818F713DADD85DE0
       C88"
   ~r:"14BEE21A18B6D8B3C93FAB08D43E739707953244FDBE924FA926D76669E7AC8C
       89DF62ED8975C2D8397A65A49DCC09F6B0AC62272741924D479354D74FF60755
       78C"
   ~s:"133330865C067A0EAF72362A65E2D7BC4E461E8C8995C3B6226A21BD1AA78F0E
       D94FE536A0DCA35534F0CD1510C41525D163FE9D74D134881E35141ED5E8E95B
       979";

   case `SHA512 ~message:"test"
   ~k:"16200813020EC986863BEDFC1B121F605C1215645018AEA1A7B215A564DE9EB1
       B38A67AA1128B80CE391C4FB71187654AAA3431027BFC7F395766CA988C964DC
       56D"
   ~r:"13E99020ABF5CEE7525D16B69B229652AB6BDF2AFFCAEF38773B4B7D08725F10
       CDB93482FDCC54EDCEE91ECA4166B2A7C6265EF0CE2BD7051B7CEF945BABD47E
       E6D"
   ~s:"1FBD0013C674AA79CB39849527916CE301C66EA7CE8B80682786AD60F98F7E78
       A19CA69EFF5C57400E3B3A0AD66CE0978214D13BAF4E9AC60752F7B155E2DE4D
       CE3"

  ] in
  [ ("public key matches", `Quick, pub_rfc) ]
  (* TODO: our deterministic generator for bit_size mod 8 <> 0 is different from RFC 6979 *)
  (* List.mapi (fun i c -> "RFC 6979 A.2.7 " ^ string_of_int i, `Quick, c) cases *)

let () =
  Mirage_crypto_rng_unix.initialize ();
  Alcotest.run "P256 EC"
    [
      ("Key exchange", key_exchange);
      ("Low level scalar mult", scalar_mult);
      ("Point validation", point_validation);
      ("Scalar validation when generating", scalar_validation);
      ("ECDSA NIST", ecdsa);
      ("ECDSA RFC 6979 P224", ecdsa_rfc6979_p224);
      ("ECDSA RFC 6979 P256", ecdsa_rfc6979_p256);
      ("ECDSA RFC 6979 P384", ecdsa_rfc6979_p384);
      ("ECDSA RFC 6979 P521", ecdsa_rfc6979_p521);
    ]
