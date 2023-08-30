package esb.bundles.core.files;

import esb.core.IBundle;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;
import promises.Promise;
import esb.common.Uri;
import esb.core.IConsumer;
import esb.logging.Logger;
import esb.core.Bus.*;

using StringTools;

@:keep
class FileConsumer implements IConsumer {
    private static var log:Logger = new Logger("esb.bundles.core.files.FileConsumer");

    public var bundle:IBundle;
    public function start(uri:Uri) {
        log.info('creating consumer for ${uri.toString()}');
        from(uri, (uri, message) -> {
            return new Promise((resolve, reject) -> {
                var fullPath = Path.normalize(uri.fullPath);
                // TODO: do better
                fullPath = fullPath.replace("C/", "C:/");
                if (!FileSystem.exists(fullPath)) {
                    FileSystem.createDirectory(fullPath);
                }

                var filename:String = uri.param("filename", "{file.name}.{file.extension}");
                for (key in message.properties.keys()) {
                    var value = message.properties.get(key);
                    filename = filename.replace("{" + key + "}", value);
                }
                var fullFilePath = Path.normalize(fullPath + "/" + filename);
                File.saveBytes(fullFilePath, message.body.toBytes());

                resolve(message);
            });
        });
    }
}