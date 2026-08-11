<?php
/**
 * openmediavault-imagecheck
 *
 * Monitor-only Docker image update checker for OpenMediaVault.
 * Exposes a small RPC service the OMV Companion Android app consumes.
 *
 * This service does NOT pull, recreate, or mutate anything. It only reports
 * whether a newer image digest exists in the registry for each running
 * container. The heavy, rate-limited registry work is done by the checker
 * script (/usr/sbin/omv-imagecheck), typically once a day via cron; the RPC
 * methods below just read that script's cached JSON result.
 *
 * Service name: "ImageCheck"
 *   - getStatus     : cheap cached count + timestamp (safe to poll often)
 *   - getUpdateList : paged per-container list for a details screen
 *   - refresh       : run the checker now (background task, streams output)
 */
class OMVRpcServiceImageCheck extends \OMV\Rpc\ServiceAbstract
{
    /** Where the checker script writes its result. */
    private $cacheFile = "/var/lib/openmediavault/imagecheck.json";

    /** The checker script that does the actual digest comparison. */
    private $checker = "/usr/sbin/omv-imagecheck";

    public function getName()
    {
        return "ImageCheck";
    }

    public function initialize()
    {
        $this->registerMethod("getStatus");
        $this->registerMethod("getUpdateList");
        $this->registerMethod("refresh");
    }

    /**
     * Read the cached result written by the checker script.
     * Always returns a well-formed array, even if the cache is missing or
     * corrupt, so callers never have to special-case a first run.
     */
    private function readCache()
    {
        $default = [
            "generatedAt" => 0,
            "checked"     => 0,
            "updateCount" => 0,
            "error"       => "",
            "images"      => [],
        ];
        if (!file_exists($this->cacheFile)) {
            return $default;
        }
        $raw = @file_get_contents($this->cacheFile);
        if ($raw === false || $raw === "") {
            return $default;
        }
        $data = json_decode($raw, true);
        if (!is_array($data)) {
            $default["error"] = "Cache file could not be parsed";
            return $default;
        }
        // Ensure every expected key exists.
        return array_merge($default, $data);
    }

    /**
     * Cheap status read. This is the method the app's alert cycle calls each
     * poll, mirroring how the package-updates count rides System.getInformation.
     * It only reads a small precomputed file, so it is safe to call often.
     */
    public function getStatus($params, $context)
    {
        $this->validateMethodContext($context, [
            "role" => OMV_ROLE_ADMINISTRATOR,
        ]);
        $data = $this->readCache();
        return [
            "updateCount" => intval($data["updateCount"]),
            "checked"     => intval($data["checked"]),
            "generatedAt" => intval($data["generatedAt"]),
            "error"       => strval($data["error"]),
        ];
    }

    /**
     * Paged list of every running container that was checked, with its local
     * vs. registry digest and whether an update is available. Backs a details
     * screen. Uses the built-in getlist param schema (start/limit/sort).
     */
    public function getUpdateList($params, $context)
    {
        $this->validateMethodContext($context, [
            "role" => OMV_ROLE_ADMINISTRATOR,
        ]);
        $this->validateMethodParams($params, "rpc.common.getlist");
        $data = $this->readCache();
        $images = $data["images"];
        if (!is_array($images)) {
            $images = [];
        }
        return $this->applyFilter(
            $images,
            $params['start'],
            $params['limit'],
            // Optional in rpc.common.getlist - the dashboard widget omits them.
            array_key_exists('sortfield', $params) ? $params['sortfield'] : null,
            array_key_exists('sortdir', $params) ? $params['sortdir'] : null
        );
    }

    /**
     * Run the checker now as a background task and stream its output, exactly
     * like Apt.update. The script writes the cache on completion; the client
     * then re-reads getStatus / getUpdateList.
     */
    public function refresh($params, $context)
    {
        $this->validateMethodContext($context, [
            "role" => OMV_ROLE_ADMINISTRATOR,
        ]);
        $checker = $this->checker;
        return $this->execBgProc(
            function ($bgStatusFilename, $bgOutputFilename) use ($checker) {
                $cmdArgs = [];
                $cmdArgs[] = $checker;
                $cmdArgs[] = '--refresh';
                $cmd = new \OMV\System\Process($cmdArgs);
                $cmd->setRedirect2to1();
                $cmdLine = $cmd->getCommandLine();
                if (0 !== $this->exec($cmdLine, $output, $bgOutputFilename)) {
                    throw new \OMV\ExecException($cmdLine, $output);
                }
                return $output;
            }
        );
    }
}
