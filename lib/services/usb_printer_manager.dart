import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:drago_usb_printer/drago_usb_printer.dart';
import 'package:drago_pos_printer/models/pos_printer.dart';
import 'package:drago_pos_printer/drago_pos_printer.dart';
import 'package:drago_pos_printer/services/printer_manager.dart';
import 'extension.dart';
import 'usb_service.dart';

/// USB Printer
class USBPrinterManager extends PrinterManager {
  Generator? generator;

  /// usb_serial
  var usbPrinter = DragoUsbPrinter();

  /// [win32]
  Pointer<Utf16> pDocName = 'My Document'.toNativeUtf16();
  Pointer<Utf16> pDataType = 'RAW'.toNativeUtf16();
  late Pointer<Utf16> szPrinterName;
  late int hPrinter;
  int? dwCount;

  USBPrinterManager(
    POSPrinter printer,
    int paperSizeWidthMM,
    int maxPerLine,
    CapabilityProfile profile, {
    int spaceBetweenRows = 5,
    int port: 9100,
  }) {
    super.printer = printer;
    super.address = printer.address;
    super.productId = printer.productId;
    super.deviceId = printer.deviceId;
    super.vendorId = printer.vendorId;
    super.paperSizeWidthMM = paperSizeWidthMM;
    super.maxPerLine = maxPerLine;
    super.profile = profile;
    super.spaceBetweenRows = spaceBetweenRows;
    super.port = port;
    generator = Generator(paperSizeWidthMM, maxPerLine, profile,
        spaceBetweenRows: spaceBetweenRows);
  }

  @override
  Future<ConnectionResponse> connect(
      {Duration? timeout: const Duration(seconds: 5)}) async {
    if (Platform.isAndroid) {
      var usbDevice = await usbPrinter.connect(vendorId!, productId!);
      if (usbDevice != null) {
        print("vendorId $vendorId, productId $productId ");
        this.isConnected = true;
        this.printer.connected = true;
        return Future<ConnectionResponse>.value(ConnectionResponse.success);
      } else {
        this.isConnected = false;
        this.printer.connected = false;
        return Future<ConnectionResponse>.value(ConnectionResponse.timeout);
      }
    } else {
      return Future<ConnectionResponse>.value(ConnectionResponse.timeout);
    }
  }

  /// [discover] let you explore all netWork printer in your network
  static Future<List<USBPrinter>> discover() async {
    var results = await USBService.findUSBPrinter();
    return results;
  }

  @override
  Future<ConnectionResponse> disconnect({Duration? timeout}) async {
    if (Platform.isAndroid) {
      await usbPrinter.close();
      this.isConnected = false;
      this.printer.connected = false;
      if (timeout != null) {
        await Future.delayed(timeout, () => null);
      }
      return ConnectionResponse.success;
    }
    return ConnectionResponse.timeout;
  }

  @override
  Future<ConnectionResponse> writeBytes(List<int> data,
      {bool isDisconnect = true}) async {
     if (Platform.isAndroid) {
      if (!this.isConnected) {
        await connect();
      }

      var bytes = Uint8List.fromList(data);
      int max = 16384;

      /// maxChunk limit on android
      var datas = bytes.chunkBy(max);
      bool? writedData;
      await Future.forEach(
          datas, (dynamic data) async {
        writedData = await usbPrinter.write(data);
        print("await usbPrinter.write(data) ${writedData}");
      });

      if(writedData == null){
        return ConnectionResponse.unknown;
      }

      if (isDisconnect) {
        try {
          await usbPrinter.close();
          this.isConnected = false;
          this.printer.connected = false;
        } catch (e) {
          return ConnectionResponse.unknown;
        }
      }
      return ConnectionResponse.success;
    } else {
      return ConnectionResponse.unsupport;
    }
  }
}
