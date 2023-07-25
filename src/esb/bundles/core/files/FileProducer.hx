package esb.bundles.core.files;

import esb.core.IBundle;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;
import esb.common.Uri;
import esb.core.IProducer;
import esb.logging.Logger;
import promises.PromiseUtils.*;
import esb.core.Bus.*;
import esb.core.bodies.RawBody;

using StringTools;

@:keep
class FileProducer implements IProducer {
    private static var log:Logger = new Logger("esb.bundles.core.files.FileProducer");

    public var bundle:IBundle;
    public function start(uri:Uri) {
        log.info('creating producer for ${uri.toString()}');
        log.info('wait for files in "${uri.path}"');
        processFolder(uri);
    }


    private static var _processing:Array<String> = [];
    private function processFolder(uri:Uri) {
        var fullPath = Path.normalize(uri.path);
        if (!FileSystem.exists(fullPath)) {
            FileSystem.createDirectory(fullPath);
        }
        var pattern:String = uri.params.get("pattern");
        var extensionPattern:String = null;
        if (pattern != null && pattern.startsWith("*.")) {
            extensionPattern = pattern.substring(2);
            pattern = null;
        }
        var folderContents = FileSystem.readDirectory(fullPath);
        var eligibleItems = [];
        for (item in folderContents) {
            var itemFullPath = Path.normalize(fullPath + "/" + item);
            if (!FileSystem.isDirectory(itemFullPath)) {
                var use = true;
                if (pattern != null || extensionPattern != null) {
                    var path = new Path(itemFullPath);
                    if (extensionPattern != null) {
                        use = path.ext == extensionPattern;
                    }
                }
                if (use == true) {
                    if (!_processing.contains(itemFullPath)) {
                        log.info('eligible file found: "${itemFullPath}"');
                        eligibleItems.push(itemFullPath);
                        _processing.push(itemFullPath);
                    }
                }
            }
        }

        var promises = [];
        for (item in eligibleItems) {
            var path = new Path(item);
            var message = createMessage(RawBody);
            message.properties.set("file.name", path.file);
            message.properties.set("file.extension", path.ext);
            message.body.fromBytes(File.getBytes(item));
            promises.push({id: item, promise: to.bind(uri, message)});
        }

        var pollInterval = uri.paramInt("pollInterval", 1000);
        var renameExtension = uri.param("renameExtension");

        /*
        var start = Sys.time();
        runAllMapped(promises).then(results -> {
            for (item in results.keys()) {
                var result = results.get(item);
                if (result != null) { // TODO: is null meaning non-failure a valid assumption?
                    if (renameExtension != null) {
                        var path = new Path(item);
                        var originalPath = item;
                        path.ext = renameExtension;
                        var newPath = path.toString();
                        log.info('renaming file "${originalPath}" -> "${newPath}"');
                        FileSystem.rename(originalPath, newPath);
                    }
                }
            }
            var end = Sys.time();
            trace("-------------------------------------------------> ALL DONE IN: ", Math.round((end - start) * 1000) + " ms");

            haxe.Timer.delay(processFolder.bind(uri), pollInterval);
            return null;
        }, error -> {
            haxe.Timer.delay(processFolder.bind(uri), pollInterval);
            trace(error);
        });
        */

        if (promises.length > 0) {
            var start = Sys.time();
            var max = promises.length;
            for (promise in promises) {
                promise.promise().then(result -> {
                    if (result != null) { // TODO: is null meaning non-failure a valid assumption?
                        var item = promise.id;
                        if (renameExtension != null) {
                            var path = new Path(item);
                            var originalPath = item;
                            path.ext = renameExtension;
                            var newPath = path.toString();
                            log.info('renaming file "${originalPath}" -> "${newPath}"');
                            FileSystem.rename(originalPath, newPath);
                        }
                        _processing.remove(item);
                    }
                    max--;
                    if (max == 0) {
                        var end = Sys.time();
                        trace("-------------------------------------------------> ALL DONE IN: ", Math.round((end - start) * 1000) + " ms");
                        //haxe.Timer.delay(processFolder.bind(uri), pollInterval);
                    }
                }, error -> {
                    trace(">>>>>>>>>>>>>>>>>>>>>>>>>> ERROR", error);
                });
            }
        } else {
            //haxe.Timer.delay(processFolder.bind(uri), pollInterval);
        }

        haxe.Timer.delay(processFolder.bind(uri), pollInterval);
    }
}