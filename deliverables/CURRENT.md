> 2026-10-14 历史整合更新：当前开发分支为 `integration/3d-main-20261014`，继续使用同一本地目录。原候选 `cloud/3d-d00aca9` 的提交完整保留在整合分支中；该旧分支名已在新分支上传核验后从本地与 GitHub 移除。当前整合状态见 [行动记录](../docs/actions/2026-10-14-main-history-integration.md)。以下保留清理交付阶段的身份信息。

# 当前交付与历史身份记录

当前工作分支：`cloud/3d-d00aca9`；仓库：<https://github.com/llylee994-ui/To-the-Human-World>。

基线 `65e640cafc3330e70c0d934404077ad98932603f`；云端候选 `d00aca9c4874117fcc924625820cf43a20c44936`（17 次提交）；Windows 启动补充 `7460d04e697c5ca7e6d312afae3cb0ef769ecc4b`。清理前安全分支 `backup/cloud-3d-before-cleanup-20261014`。

当前启动见 [Windows 说明](../docs/WINDOWS-RUN.md)，清理及本机验收见 [行动记录](../docs/actions/2026-10-14-independent-cleanup.md)。本轮无上传、推送或发布。

以下是**历史交付身份，不是当前运行命令或有效本地下载位置**。原始文件可从上述安全提交恢复。上传成功与 Windows xattr 回写失败分别记录；不把旧候选交付视为当前美术验收。


## deliverables/DELIVERY_STATUS.md

原文件 2639 字节，SHA256 `2b773d0f0d03b42fb626acbe4a5b1e65ffd6474fc70984b139963fa566b781cb`。完整历史正文/压缩包保存在安全提交。


## deliverables/FINAL_DELIVERY.json

```json
{
  "version": "D3-LAB-20261012-r3-v01",
  "files": [
    {
      "local_path": "D:\\taptap\\To-the-Human-World-3D-Lab\\REPORT.md",
      "library_file_id": "libfile_2b7899edaabc819199c5b25a46bd693c",
      "version": 2,
      "upload_status": "succeeded",
      "size": 9434,
      "sha256": "df52a9ceb84a32fb36a364c46b0c749a7951e14d440a956dbc99b5e86e9e34b1",
      "metadata_writeback_exit": 1,
      "metadata_writeback_error": "Historical Windows os.setxattr unsupported; original traceback preserved in safety commit"
    },
    {
      "local_path": "D:\\taptap\\To-the-Human-World-3D-Lab\\deliverables\\D3-LAB-20261012-r3-v01-review.zip",
      "library_file_id": "libfile_a96a3b502d5c8191a8fab49a5d70d685",
      "version": 2,
      "upload_status": "succeeded",
      "size": 26704859,
      "sha256": "e594d5224f6e54e73f3c717d4a7ec07b9480f50d2909a33af2110c7cab42785e",
      "metadata_writeback_exit": 1,
      "metadata_writeback_error": "Historical Windows os.setxattr unsupported; original traceback preserved in safety commit"
    }
  ],
  "note": "Library replacements succeeded. Windows official xattr writeback failed; receipts preserve identities/versions. No credential or input reference uploaded."
}
```


## deliverables/github-push-receipt.json

```json
{
  "utc": "2026-10-12T05:26:08.238168+00:00",
  "repository": "https://github.com/llylee994-ui/To-the-Human-World",
  "branch": "experiment/3d-lab",
  "commit": "6d4829df6d3af0b6c2f2d114dd7b32da9d6ab997",
  "remote_sha_verified": true,
  "base": "d1b2d06cb31948a33b1e8d7bfbadb858550255af",
  "additions": 135,
  "modifications": 0,
  "deletions": 0,
  "subdirectory": "experiments/3d-lab",
  "formal_worktree_mutated": false,
  "review": "deliverables/github-stage-review.json",
  "visibility": "Unverified; GitHub connector metadata returned 404 but existing local Git authentication successfully cloned and pushed the explicitly authorized destination.",
  "local_checkout": "D:\\taptap\\To-the-Human-World-3D-Lab\\deliverables\\github-checkout"
}
```


## deliverables/github-snapshot-review.json

```json
{
  "utc": "2026-10-12T05:21:12.920162+00:00",
  "destination": "D:\\taptap\\To-the-Human-World-3D-Lab\\deliverables\\github-checkout\\experiments\\3d-lab",
  "branch": "experiment/3d-lab",
  "remote_base": "d1b2d06cb31948a33b1e8d7bfbadb858550255af",
  "files": 134,
  "total_bytes": 3125592,
  "largest_bytes": 722007,
  "secret_pattern_hits": [],
  "source_was_lab_only": true,
  "remote_files_modified_or_deleted": false
}
```


## deliverables/github-stage-review.json

```json
{
  "utc": "2026-10-12T05:24:12.497386+00:00",
  "review": "PASS",
  "branch": "experiment/3d-lab",
  "base": "d1b2d06cb31948a33b1e8d7bfbadb858550255af",
  "staged_additions": 135,
  "modifications": 0,
  "deletions": 0,
  "total_bytes": 3125667,
  "largest_bytes": 722007,
  "all_index_blobs_match_disk_and_source_manifest": true,
  "secret_pattern_hits": [],
  "whitespace": "Application/new documentation passed with cr-at-eol. Existing imported Label/RichText trailing blanks and untouched raw offline log trailing spaces preserved as source evidence; not a functional failure.",
  "files": [
    {
      "path": "experiments/3d-lab/.gitattributes",
      "bytes": 75,
      "sha256": "22d460c8d3205c7c59f46153a18170cee4971a35ccd1f7fe8b8e5598c361a2fe"
    },
    {
      "path": "experiments/3d-lab/.gitignore",
      "bytes": 180,
      "sha256": "75b0a7a360f8793a30188ca565f345f7a451b0d3a1426720bf0430e4887c8f05"
    },
    {
      "path": "experiments/3d-lab/README.md",
      "bytes": 4129,
      "sha256": "f22208cac949ceb14921220c3ed3838fbed46ea00ad9def6ac49f5d6ae67b961"
    },
    {
      "path": "experiments/3d-lab/SOURCE_MANIFEST.json",
      "bytes": 71073,
      "sha256": "5619e4d75ab4d3af4d6d39d9f3223597d8fd547d5e148f010f2d4cd0061a652b"
    },
    {
      "path": "experiments/3d-lab/docs/3d-interface-map.md",
      "bytes": 5289,
      "sha256": "93c2d9b21a6c6c654b63ebab3916b20e60d3298f94eb7909e4edd7da07556143"
    },
    {
      "path": "experiments/3d-lab/docs/evidence/3d-lab-r3/native-summary.json",
      "bytes": 2528,
      "sha256": "77815ff0d39b52a3c5c6978b83a7cd66dcc4766ce9b929e554b0788d033b05da"
    },
    {
      "path": "experiments/3d-lab/docs/evidence/3d-lab-r3/offline-checks.json",
      "bytes": 25555,
      "sha256": "f63e8adac6691cfaa1042a96416036afdc830806561cf892137985846ba596af"
    },
    {
      "path": "experiments/3d-lab/docs/evidence/3d-lab-r3/offline-checks.log",
      "bytes": 6778,
      "sha256": "10b241f0fd7fafbcce88f01e9c2b057c3030296f152c6f9096257a8f045685da"
    },
    {
      "path": "experiments/3d-lab/scripts/core/EventBus.lua",
      "bytes": 5845,
      "sha256": "f53bce9dfe7c18ea854d50f7413b339bf32904acfc469bde7044d4231a35f92a"
    },
    {
      "path": "experiments/3d-lab/scripts/core/GameFlow.lua",
      "bytes": 7736,
      "sha256": "2c483fa0880fab20f7109e8db3369efe7fbdb0d69d469450134de5bc5b6b0eb4"
    },
    {
      "path": "experiments/3d-lab/scripts/core/GameSession.lua",
      "bytes": 2543,
      "sha256": "3fa6ab2a5fa1ecf5419f5e6b1c15ab6ca7644bd6af93e8a9ee0d7ae9627a0f33"
    },
    {
      "path": "experiments/3d-lab/scripts/core/GameState.lua",
      "bytes": 27083,
      "sha256": "f49dfbc15c161070dec3902742d1e737d472f01a37d8335742b703fd5765c978"
    },
    {
      "path": "experiments/3d-lab/scripts/core/SaveJson.lua",
      "bytes": 3057,
      "sha256": "407249e9959bb17b1099d1338302a5e3ad7ef04165d219f25afcd8909518a880"
    },
    {
      "path": "experiments/3d-lab/scripts/core/SaveMigrations.lua",
      "bytes": 2270,
      "sha256": "01e8f797485f25105299d6f0ce273b06de454abef3b3834a602bb0700e41ae43"
    },
    {
      "path": "experiments/3d-lab/scripts/core/SaveSchema.lua",
      "bytes": 17422,
      "sha256": "b67a2822b37e92831a6caf89955266123885dfce6d656985cf69574b95bf5d98"
    },
    {
      "path": "experiments/3d-lab/scripts/core/SaveSystem.lua",
      "bytes": 8166,
      "sha256": "cb1b2a2a160d5cf6819f6ce081dcd9eed434eb572264983c7da048a6f1043eb4"
    },
    {
      "path": "experiments/3d-lab/scripts/core/SchemaProjection.lua",
      "bytes": 957,
      "sha256": "f41bec1d9e99eddd29932237babc84b76340c9d5b0786d21acd1e5cc3b8a7abf"
    },
    {
      "path": "experiments/3d-lab/scripts/core/StateUtil.lua",
      "bytes": 2972,
      "sha256": "87b7818d2c4fce1325c1db6bc8b2e6b27ac48aec66f59d162d99e0d105cb336e"
    },
    {
      "path": "experiments/3d-lab/scripts/data/content.lua",
      "bytes": 75281,
      "sha256": "31321c3836b3a927b798e012e4caff7ed48d773410f24e5fbc67ce71e4b514b5"
    },
    {
      "path": "experiments/3d-lab/scripts/data/effects.lua",
      "bytes": 3815,
      "sha256": "a88c061d34a5b3b91ac6c51392f482b0de70f9a6ea77007ff4759b80ebb9c540"
    },
    {
      "path": "experiments/3d-lab/scripts/data/equipment.lua",
      "bytes": 1596,
      "sha256": "05543c85f8fa6ef50cd9fdb037f38aa14d99512deab81aa8f279af6c3e797c29"
    },
    {
      "path": "experiments/3d-lab/scripts/data/extension_test.lua",
      "bytes": 8918,
      "sha256": "7395aac16f27c7dfe04253339a5bd54a2b6a2aa3a3f7b05cb34d53cbb2d8b5d3"
    },
    {
      "path": "experiments/3d-lab/scripts/data/followup.lua",
      "bytes": 26049,
      "sha256": "f26732ee4227d1c720ad724e101e4a90a05b37ec8be222b8c0bed3bafb7300aa"
    },
    {
      "path": "experiments/3d-lab/scripts/data/gameplay.lua",
      "bytes": 132,
      "sha256": "e6325f44002ab0c19bd808378a1343a7db679acfca5f5b242f2ec4a015c3e53d"
    },
    {
      "path": "experiments/3d-lab/scripts/data/ingredients.lua",
      "bytes": 2012,
      "sha256": "5a9c9a756ff8dd6fda44dba54e4101fb7cb99fc762e82606e55f5c10b69ed0d8"
    },
    {
      "path": "experiments/3d-lab/scripts/data/letters.lua",
      "bytes": 7592,
      "sha256": "0920255a04e3d0a4ef26f7445befe845b2651b6db1833d7818e5aef40840b2b7"
    },
    {
      "path": "experiments/3d-lab/scripts/data/npcs.lua",
      "bytes": 3662,
      "sha256": "10e1cd5556ed7c74c28815e5fed034f038f56bf18c97637d0fb2304a8481278b"
    },
    {
      "path": "experiments/3d-lab/scripts/data/numeric_v02.lua",
      "bytes": 722007,
      "sha256": "2a3c99a732b902fac65b03311640e47a70cce1c13bf54406b88be707e739c886"
    },
    {
      "path": "experiments/3d-lab/scripts/data/ordinary_orders.lua",
      "bytes": 50512,
      "sha256": "d6124a6c9069ea7baf7cd1b2757bbf68bd15fe6f67ca4994712fa6453ccbebd0"
    },
    {
      "path": "experiments/3d-lab/scripts/data/recipes.lua",
      "bytes": 19103,
      "sha256": "303718e3d720f24b6a0a2b169bf5ae58650b49974ead1a8e36b06a2947f4b499"
    },
    {
      "path": "experiments/3d-lab/scripts/data/stage1.lua",
      "bytes": 22115,
      "sha256": "70c396a2a6a40d29ad39a6a547f60567d222ab0a4febdee14554d97a33033132"
    },
    {
      "path": "experiments/3d-lab/scripts/data/synthesis.lua",
      "bytes": 3818,
      "sha256": "0b36bbc69e584655d5f574ea977b397fe840b4ea0a0a41bbac94505234582dee"
    },
    {
      "path": "experiments/3d-lab/scripts/data/word_profiles.lua",
      "bytes": 3155,
      "sha256": "c3d0a31814ccb3c409c9a56fcacbf52e4873706ade52eb33eceec51a24245dde"
    },
    {
      "path": "experiments/3d-lab/scripts/data/words.lua",
      "bytes": 9541,
      "sha256": "f84ad8e6408af4129efbfd3ad75125d5f734a2cf92231cb3f21cdaf52746b873"
    },
    {
      "path": "experiments/3d-lab/scripts/lab/Bootstrap.lua",
      "bytes": 999,
      "sha256": "4d53eec8dc35f416c5958fd06105e57d31337ef57acc317f75102f26f3739fde"
    },
    {
      "path": "experiments/3d-lab/scripts/lab/CameraRig.lua",
      "bytes": 2438,
      "sha256": "359c89c8efd71c8295ba7c8b4c0ca666d640e413c271a97cfb5ae6bcb241f019"
    },
    {
      "path": "experiments/3d-lab/scripts/lab/Hud.lua",
      "bytes": 7424,
      "sha256": "2d8bcaf79781bfad563b308188284631bc287c9241dfcce834757bd03bd9786e"
    },
    {
      "path": "experiments/3d-lab/scripts/lab/Interaction.lua",
      "bytes": 3661,
      "sha256": "bd4846d2ae4a511e4a6ed578e3a0161ceec36de1c18786bbe51e241db79daa47"
    },
    {
      "path": "experiments/3d-lab/scripts/lab/MemoryStorage.lua",
      "bytes": 1170,
      "sha256": "f63f87fbccc3aaff3640d0b154aa7c3ddd3ad881de421d11ae9564664ea683ec"
    },
    {
      "path": "experiments/3d-lab/scripts/lab/NativeQA.lua",
      "bytes": 9322,
      "sha256": "d9d3a74bf05030dc45be345023a6e35372d0b6fef0deed3f7307edcd117e65dc"
    },
    {
      "path": "experiments/3d-lab/scripts/lab/QAConfig.lua",
      "bytes": 99,
      "sha256": "31e02fb5aff5ac52a6d39097226ecab15eea19dd61cfc9b70e3bd720b734d611"
    },
    {
      "path": "experiments/3d-lab/scripts/lab/SceneView.lua",
      "bytes": 5420,
      "sha256": "f0f88cb7cd6e3d1dfd3f818e96ab0d0ef9a2760707c3c46490dbc6459ebc9abe"
    },
    {
      "path": "experiments/3d-lab/scripts/lab/Spatial.lua",
      "bytes": 1901,
      "sha256": "339e5505cebc7c3711e970a16eebc70b123c67a95455eea9150ea79c0cbc49d0"
    },
    {
      "path": "experiments/3d-lab/scripts/lab/World.lua",
      "bytes": 5788,
      "sha256": "06d39581cf474d9326607ec0dcd5d982dceb6efc19119c998250c4c9b0d6232d"
    },
    {
      "path": "experiments/3d-lab/scripts/lab/tests/Checks.lua",
      "bytes": 10493,
      "sha256": "29831fb7aa399bb36547b29ed6f6e632630a181f76e36a91118c6994dcee4291"
    },
    {
      "path": "experiments/3d-lab/scripts/lab/tests/HeadlessUI.lua",
      "bytes": 1746,
      "sha256": "31ae416f2fd58058766364081aec9cdfcb20954322c8f3b58de4a60ffbad376f"
    },
    {
      "path": "experiments/3d-lab/scripts/main.lua",
      "bytes": 1934,
      "sha256": "c348b8804781b2d9bf1b606ee6dfe7a4b1638ccd06a59c2359845e3d38163f67"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/BrewJournal.lua",
      "bytes": 9264,
      "sha256": "69da411b9869af81c40f944b6fec5b166a1584d3f0faa2fbee6b51bbde72e960"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/CalculationGuard.lua",
      "bytes": 2452,
      "sha256": "4bf700587c59567216b5d3a2d858d6abdb1f99f1c5984fbed1ac7320a30af514"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/CaseBoardProjection.lua",
      "bytes": 239,
      "sha256": "eea82e94beba0f1c7f98a9aa9b173f9da3410580b9916495827abdf88cbe90b7"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/Economy.lua",
      "bytes": 12823,
      "sha256": "2c06697f099ace07facd4f7c4f035ae3898c5145fc0c78f5fb2799cdfb22ee7b"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/Letter.lua",
      "bytes": 14360,
      "sha256": "a1cf42f86fa72a4a40e52059d4d9f98bd38a65ad52a329ccc22896889579476f"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/Narrative.lua",
      "bytes": 15635,
      "sha256": "fa605094d07db107e6c1e7e25fe14c5c9fa17c485e00140ac8c60cc3de0829db"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/Order.lua",
      "bytes": 15707,
      "sha256": "be2944ec7650ab051f7ac2a71823ea1fe0292340c8b6848b136d7e0705494856"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/OrderAudit.lua",
      "bytes": 17343,
      "sha256": "22828caef710319e3eb959afe6648bc5c37a153b9d8a4ad5f649f115c20d6817"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/OrderLifecycle.lua",
      "bytes": 17290,
      "sha256": "5fe1da2555da9380f97d4f606e0c20505a319ecd1f2188dacc8ca4d7d37c8eb2"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/OrderTrial.lua",
      "bytes": 11319,
      "sha256": "ef4bb679396fe194a1c3bfd22d4fd0ff9b014b491db00b5ceac09d03d1c8cb12"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/PlayQueries.lua",
      "bytes": 8874,
      "sha256": "4e49e5d4456d66efb42976e32c35ce49d10798fc830f0d702c08e223d7b28b4e"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/Potion.lua",
      "bytes": 20940,
      "sha256": "b5409bc71d75e61559d66252fcb27d5be28b643cc23f5e592075be11a879b2bf"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/RecipeDraft.lua",
      "bytes": 3278,
      "sha256": "e0c3d3ec4560d221cfb89109a467aedd58f61e8b8645a5b7f992545503718c5f"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/StoryRules.lua",
      "bytes": 8185,
      "sha256": "fd82030a80c43af20c1dbd442ff89a77c138cdb0391522f26af14f05a2cbf7d4"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/WordToken.lua",
      "bytes": 10030,
      "sha256": "09370a5d87002137e7ac19cc9771910bfee7fbe6f8884837c7c852879c504bcd"
    },
    {
      "path": "experiments/3d-lab/scripts/systems/WorldState.lua",
      "bytes": 9677,
      "sha256": "38ae49b262976686239c3c3d6f1007d3de75464c0cc2c025569121e5c5ef6c1f"
    },
    {
      "path": "experiments/3d-lab/scripts/ui/PlayModel.lua",
      "bytes": 15883,
      "sha256": "d75787e020b59c23c88f43e50acce611aa44ab9d190e7934839e5833963b395f"
    },
    {
      "path": "experiments/3d-lab/scripts/ui/landscape/LayoutManifest.lua",
      "bytes": 13873,
      "sha256": "58191586f3f4d648de56ec978527eb0dcb0a38b0dedc9d9efe319e32ca0153ad"
    },
    {
      "path": "experiments/3d-lab/scripts/ui/landscape/Panels.lua",
      "bytes": 16188,
      "sha256": "b885a9abede83b18403d648a33e2e1452272b5fd8e6dceff847215f6a47cdee9"
    },
    {
      "path": "experiments/3d-lab/tools/run_checks.py",
      "bytes": 2384,
      "sha256": "cc39089de91d830d41ec9aadb0737b7fa3994e61a429ed14bf40d92609f2e93b"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/Sprite/SpriteAnimator.lua",
      "bytes": 15638,
      "sha256": "a63b2854ea0fb976d59978babfd26923c79303112df3d98e3d248a4479f15c0e"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/Sprite/SpriteSheet.lua",
      "bytes": 22385,
      "sha256": "c49b537026e63170506033cec029d45fc720b586b9e8736381f3012d4294d053"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Components/ChatWindow.lua",
      "bytes": 13593,
      "sha256": "4e629ae5258f71e364060c688560282eb1ec20537a7a1c622beae76b89f31cd3"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Components/DragDropContext.lua",
      "bytes": 8748,
      "sha256": "bc6820d8a4b1a6e6f39ab6e2704eec2a3f62da98029c07ae344fc4747bfe8fc0"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Components/InventoryManager.lua",
      "bytes": 8681,
      "sha256": "deaebd09ba497a3a03a1fd456340c058b5d066b66aa73154cb2171d4edbbd752"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Components/ItemSlot.lua",
      "bytes": 9039,
      "sha256": "5e94f034686d8a849edd0bd06dd664acb7ddc91f6bdc614901257a59543995d2"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Components/ItemTooltip.lua",
      "bytes": 10799,
      "sha256": "ac7904da1318cd50f5a2ff7cacfc2c0e988fb625648f67a511b445367e92ef3f"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Components/SkillTree.lua",
      "bytes": 20021,
      "sha256": "2d08017fb535569881468eafd71d13834672e8cabf2dbd3b6b984fce2afced23"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Components/VirtualList.lua",
      "bytes": 13707,
      "sha256": "0d64174af8e4df408d835a454b80240d1df5a1d60688826fcac7007f16b80e5d"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Core/Gesture.lua",
      "bytes": 18344,
      "sha256": "5ac07eaf16c13cca115fc929105122ebb7b86ff3036a7e1657a5755b2122f006"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Core/GestureEvent.lua",
      "bytes": 7194,
      "sha256": "901ebce018ab618cb21d87dca8d6aee7e80350dad1009068d54e4148a3fea7a9"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Core/ImageCache.lua",
      "bytes": 4091,
      "sha256": "3773f2704b7d7b51bb9e6f224e372a0d0dade625c6339964e30e1332ec8389e8"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Core/Input.lua",
      "bytes": 8140,
      "sha256": "2f83e6dee292c5d0d0a41d10861cf4d0b8d00a921f2009778471824a2b1027d7"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Core/InputAdapter.lua",
      "bytes": 10954,
      "sha256": "2878bc47003faaa09a2249ca8520520d33061ac284ea42e20bc82185bd9973f7"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Core/PointerEvent.lua",
      "bytes": 8027,
      "sha256": "753d6557be63d7c00cc9f5c8b5219a27acd41ef67021e86918dbe097a44af2ae"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Core/Style.lua",
      "bytes": 13760,
      "sha256": "7ace494a67f881d98886e58d1219aef3a482a7cb22dcd4a13798d9ef6ca086bd"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Core/Theme.lua",
      "bytes": 15809,
      "sha256": "311c3fb128a90a838a7e951baa3968bf720f030721adbc3bbec7bcd9896bc2a4"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Core/Transition.lua",
      "bytes": 21756,
      "sha256": "208fae3334d2ef24cbbf2b298009512b632dd902c540b79e391a34f50ae826d5"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Core/UI.lua",
      "bytes": 106748,
      "sha256": "71f48aaa663adbce0b3b12c7d0753da4c7642383dcb03ec965bc9c3c829865e5"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Core/UILoader.lua",
      "bytes": 16595,
      "sha256": "9bb93883e134058220702d490c7b07375d5d4f471e58b6dd4a135ad522e11447"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Core/UISerializer.lua",
      "bytes": 3492,
      "sha256": "3f71dc2d3135f38a2e1ad115af01220ca9e9d87b1e14dcef861b090fc449c9cd"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Core/Widget.lua",
      "bytes": 181166,
      "sha256": "aa4f6e9b667f0681ccb9c0df4a7e727c1ac204afb5f8fb4ec6eeb57f62e4128d"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Accordion.lua",
      "bytes": 29530,
      "sha256": "b76e98997625df81f9bbd9605d2ba6e8f2e1e184d2bf8316fdfb22b118835ee5"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Alert.lua",
      "bytes": 24033,
      "sha256": "f765eb91dd88a4bf39fdaf8d02bb9d2aa8dc5fde57a50650ca696f59e429405d"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Avatar.lua",
      "bytes": 17037,
      "sha256": "5c8b4549f2e71d83f3d9237619bdbf4825294b2b167aecd55f6c4e49d09a8ba5"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Badge.lua",
      "bytes": 15371,
      "sha256": "5ad14a1c5743a64a7de5a69c38d44cbd4384ef5b8bbc9c28be94f0236dce6f8f"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Breadcrumb.lua",
      "bytes": 15784,
      "sha256": "a65997f91ddf1a62a45b04564a540fe45318076eba60edd44f2282acc7b12399"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Button.lua",
      "bytes": 34676,
      "sha256": "4841a1871db8ef78c557b2ee65d0c5f3c3fe877bc92f82feb7842d67c7bac6ef"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Calendar.lua",
      "bytes": 23469,
      "sha256": "f8040644b377d871c2bfefa4290190bc4646e2751b5dabdfb40606dd0f1a26bb"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Card.lua",
      "bytes": 20239,
      "sha256": "e3ec549b58b10315b9d9dd3337dac54e512b6aaad06e2759a95f9edaec6644ea"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Carousel.lua",
      "bytes": 26945,
      "sha256": "4be5570de303758b559f17a4e297cf4703fc6874a326c6df6a1ba50c23330aa6"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Checkbox.lua",
      "bytes": 9308,
      "sha256": "926907a27b2af85040f57d67673b55c816b2c877a04f66ca491031d56f147543"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Chip.lua",
      "bytes": 23780,
      "sha256": "18cd5cd933ba7f9cb77ab83f2636ae85bcc434002e5114ac2924cebec40df1a0"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/ColorPicker.lua",
      "bytes": 43873,
      "sha256": "f0bb51c44397bad1a09d8ece02e7bfaac1adcc9760504cb9fc15aadb16608f90"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/DatePicker.lua",
      "bytes": 47545,
      "sha256": "cfff3a75e979c29b7b9a713289ccb831d6166d567492f1a14a8b53801dc8c255"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Divider.lua",
      "bytes": 11128,
      "sha256": "9c5f755897e79b712157e3881f0bbec2a60232b379fedfce4ba14af13b14bb73"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Drawer.lua",
      "bytes": 25242,
      "sha256": "111e08a503c7ec64bb09519deea2e3abac22606d0997ed029768f01173847ac0"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Dropdown.lua",
      "bytes": 35118,
      "sha256": "c1c607da9bd10bc6b2ed3e57f25bb71a94601f194e20bb06b87cade5c8dc531e"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/EditMenu.lua",
      "bytes": 10832,
      "sha256": "5c4c516fe2e19500bc42a310d07f5d7e928d9b0479c79b9bac8c6df193e67eb8"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/FileUpload.lua",
      "bytes": 26164,
      "sha256": "6cbcb13671e277d70b7242088a89347a63f8a96aa5cbac43a4a8a415648501d9"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Label.lua",
      "bytes": 57371,
      "sha256": "c04904aae6257963685b94b273f23ce343848d92b85252002c653475ed25cc03"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/List.lua",
      "bytes": 29318,
      "sha256": "28262cda1dd80ad766933cf433832c7e14a55d7dbb17dce9f285bf2a27c5093e"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Menu.lua",
      "bytes": 33126,
      "sha256": "c0efe11be927516bc90ca10bf33a0cfbf981891d72fef88951ac9bcf0cb2b152"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Modal.lua",
      "bytes": 32066,
      "sha256": "627d07f4e86092eb7cf774192ca66cff2c40df44da208f86c2546ea38d966a2a"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Pagination.lua",
      "bytes": 28202,
      "sha256": "b3e3275d09e62c2cd26b291150ed7a573d2000955c3e9496de38a5b6f03d1a30"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Panel.lua",
      "bytes": 2597,
      "sha256": "0519b7b27605210069735a2a07530b7d74fc02ae6cca45e888e59aa09b1f4e26"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Popover.lua",
      "bytes": 20626,
      "sha256": "1e2de43bd61a9fa7cf500d285f3b276af2b373e62e9d859862e2f03e6c5cfd4e"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/ProgressBar.lua",
      "bytes": 10469,
      "sha256": "e727d2b25e5e68ac49513ded226c95fcb558515fbe1912cdf2f09aee02487671"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Rating.lua",
      "bytes": 19435,
      "sha256": "6d9acc9ea984078b5331c561ae15c654c618f3c5fe63f4e6dff0c94d032b01b8"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/RichText.lua",
      "bytes": 30962,
      "sha256": "c50b75ca28890f40b98cfb1519ab380d79f809f611bf135b77520017d19fe714"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/SafeAreaView.lua",
      "bytes": 9904,
      "sha256": "22c0f9a9cc706e57c6c5366598c64bb24b42344780a957dad9c23a7bdf407472"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/ScrollView.lua",
      "bytes": 42321,
      "sha256": "0cc6da4947926cbf8bb642af4099675ea24fa46461c9a294a46d188a39427202"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/SimpleGrid.lua",
      "bytes": 9274,
      "sha256": "76c1d7cc0ade7c66142df74741602235efc90a91529312524111d95148dfc6a5"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Skeleton.lua",
      "bytes": 17103,
      "sha256": "77933dbf040df77ecec4f1ba76f10b814ab2591e68416312f53e4e2639c99df5"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Slider.lua",
      "bytes": 14128,
      "sha256": "d81ba221e18640b3dc02dc8eec48051bc2a9f9c247a6ba1f8a4b7b3dcd0490e8"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Spine.lua",
      "bytes": 13332,
      "sha256": "90e6cc19ac05ca634352abd05eab0f060b574a5fadc25b258e773a9ce407a393"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Sprite.lua",
      "bytes": 40512,
      "sha256": "12ad6180b7c7e25cb040e0c38374b5041f35d79410b4c967c26625014a0b9eda"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Stepper.lua",
      "bytes": 31708,
      "sha256": "21531a0e76599576d09bc2c6d121f4237b1ade1437bf0d0d4974b7c24df6c1cb"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Table.lua",
      "bytes": 32465,
      "sha256": "903005134b624b13dc2792f9712385511b12b1a715730ccd7c22de312021ba69"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Tabs.lua",
      "bytes": 41585,
      "sha256": "b2920342912ace6ba5242d59cfe149994e907cf4fc8e8a0c818f9a20bc0836ec"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/TextField.lua",
      "bytes": 34663,
      "sha256": "de85be958d6f1ffc5a4bd5ecb73ebef89056c50b0d8bd1fb1048dc617c49337d"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/TimePicker.lua",
      "bytes": 45312,
      "sha256": "a999f87936cd9ab5b7af716aa1295288a155889eedf4ab4e0aa893fa1b17774e"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Timeline.lua",
      "bytes": 26050,
      "sha256": "270c2d78a8b55b93755b82df835699ff79e75d34017581fc4c6e1758e882169c"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Toast.lua",
      "bytes": 25320,
      "sha256": "749bc261f6da7ec1fac5d02caad2a5ba7f293a3af8f27bbddc4481eee796e78f"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Toggle.lua",
      "bytes": 9790,
      "sha256": "645907a30de6b7e9b358709f9888d7142dc5ff5b7b35246fdf93711a3f4af6fe"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Tooltip.lua",
      "bytes": 12644,
      "sha256": "93ef6d997b5a35fe6c10a30e7d92e48327d8fede6fd34bafdb8a1e470dbbdd43"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/Widgets/Tree.lua",
      "bytes": 35607,
      "sha256": "f43caaf8e3c04dffee68b6801420c83006df78135fe1b9517da8e54918779d19"
    },
    {
      "path": "experiments/3d-lab/urhox-libs/UI/init.lua",
      "bytes": 9911,
      "sha256": "41a44475e29a1172bca0f415f1608ae5e8260e4d7337fa72ea6bdc5caa13c58c"
    }
  ]
}
```


## deliverables/history/2026-10-11-v01/D3-LAB-20261012-r3-v01-review.zip

原文件 1270907 字节，SHA256 `a15cff201a1e9cbfcd3ee0e062d665b955644c13486a4f9c2c32cbb3afdd0898`。完整历史正文/压缩包保存在安全提交。


## deliverables/history/2026-10-11-v01/receipt.json

```json
{
  "path": "D:\\taptap\\To-the-Human-World-3D-Lab\\deliverables\\D3-LAB-20261012-r3-v01-review.zip",
  "size": 1270907,
  "sha256": "a15cff201a1e9cbfcd3ee0e062d665b955644c13486a4f9c2c32cbb3afdd0898",
  "files": 432,
  "report_path": "D:\\taptap\\To-the-Human-World-3D-Lab\\REPORT.md",
  "report_size": 9113
}
```


## deliverables/history/2026-10-11-v01/REPORT.md

原文件 9113 字节，SHA256 `6d2e2b809eb3e9cf6c00fa7defc2a4a4778441f53c281c60ee22ce6063ab4427`。完整历史正文/压缩包保存在安全提交。


## deliverables/history/2026-10-12-before-native/LAB_STATUS.md

原文件 3438 字节，SHA256 `eab11b8a88590e409fd22e56c18e8fd496c079eb685766d15eabaa874c81fda6`。完整历史正文/压缩包保存在安全提交。


## deliverables/history/2026-10-12-before-native/REPORT.md

原文件 10366 字节，SHA256 `60a0ed4e33df78a91675ff03ef8989fa3bfcfd26855beaa954d144bd19c733bc`。完整历史正文/压缩包保存在安全提交。


## deliverables/library-direct-result.json

```json
{
  "content": [
    {
      "type": "text",
      "text": "Action completed."
    }
  ],
  "structuredContent": {
    "results": [
      {
        "operation": "create_library_file",
        "status": "succeeded",
        "path": "/REPORT.md",
        "file_id": "file_0000000095a482078b96b67a69cdd6d5",
        "library_file_id": "libfile_2b7899edaabc819199c5b25a46bd693c",
        "file_name": "REPORT.md",
        "current_version_number": 0,
        "restored_from_version_number": null,
        "xattrs": [
          {
            "name": "user.library-file-version",
            "value": "0"
          }
        ],
        "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
        "mime_type": "text/markdown",
        "library_artifact_type": "other",
        "file_size_bytes": 9113
      },
      {
        "operation": "create_library_file",
        "status": "succeeded",
        "path": "/D3-LAB-20261012-r3-v01-review.zip",
        "file_id": "file_0000000071548207aa38475097f13677",
        "library_file_id": "libfile_a96a3b502d5c8191a8fab49a5d70d685",
        "file_name": "D3-LAB-20261012-r3-v01-review.zip",
        "current_version_number": 0,
        "restored_from_version_number": null,
        "xattrs": [
          {
            "name": "user.library-file-version",
            "value": "0"
          }
        ],
        "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
        "mime_type": "application/zip",
        "library_artifact_type": "other",
        "file_size_bytes": 1270907
      }
    ],
    "warnings": [],
    "external_connectors_accessed": false
  },
  "isError": false
}
```


## deliverables/library-final-native-replace-20261012.json

```json
{
  "report": {
    "operation": "replace_library_file",
    "status": "succeeded",
    "path": "/REPORT.md",
    "file_id": "file_0000000064308208b75457044c7b45cc",
    "library_file_id": "libfile_2b7899edaabc819199c5b25a46bd693c",
    "file_name": "REPORT.md",
    "current_version_number": 2,
    "restored_from_version_number": null,
    "xattrs": [
      {
        "name": "user.library-file-version",
        "value": "2"
      }
    ],
    "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
    "mime_type": "text/markdown",
    "library_artifact_type": "other",
    "file_size_bytes": 9434,
    "external_connectors_accessed": false
  },
  "review": {
    "operation": "replace_library_file",
    "status": "succeeded",
    "path": "/D3-LAB-20261012-r3-v01-review.zip",
    "file_id": "file_00000000533882118034d14af43be0bf",
    "library_file_id": "libfile_a96a3b502d5c8191a8fab49a5d70d685",
    "file_name": "D3-LAB-20261012-r3-v01-review.zip",
    "current_version_number": 2,
    "restored_from_version_number": null,
    "xattrs": [
      {
        "name": "user.library-file-version",
        "value": "2"
      }
    ],
    "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
    "mime_type": "application/zip",
    "library_artifact_type": "other",
    "file_size_bytes": 26704859,
    "external_connectors_accessed": false
  },
  "local_review_sha256": "e594d5224f6e54e73f3c717d4a7ec07b9480f50d2909a33af2110c7cab42785e",
  "local_report_sha256": "df52a9ceb84a32fb36a364c46b0c749a7951e14d440a956dbc99b5e86e9e34b1"
}
```


## deliverables/library-home-art-a-first.json

```json
{
  "content": [
    {
      "type": "text",
      "text": "Action completed."
    }
  ],
  "structuredContent": {
    "operation": "create_library_file",
    "status": "succeeded",
    "path": "/0002-20261012T053933658Z.png",
    "file_id": "file_0000000047b88211a556560079b10c88",
    "library_file_id": "libfile_b0c43d58a38c8191be8cba00999f9de4",
    "file_name": "0002-20261012T053933658Z.png",
    "current_version_number": 0,
    "restored_from_version_number": null,
    "xattrs": [
      {
        "name": "user.library-file-version",
        "value": "0"
      }
    ],
    "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
    "mime_type": "image/png",
    "library_artifact_type": "image",
    "file_size_bytes": 902552,
    "external_connectors_accessed": false
  },
  "isError": false
}
```


## deliverables/library-master-home-progress.json

```json
{
  "content": [
    {
      "type": "text",
      "text": "Action completed."
    }
  ],
  "structuredContent": {
    "operation": "create_library_file",
    "status": "succeeded",
    "path": "/MASTER_HOME_PROGRESS_20261012.md",
    "file_id": "file_000000002d10821191a251d681bc1179",
    "library_file_id": "libfile_2f70f0417bc48191b8ee276b35ed9d9c",
    "file_name": "MASTER_HOME_PROGRESS_20261012.md",
    "current_version_number": 0,
    "restored_from_version_number": null,
    "xattrs": [
      {
        "name": "user.library-file-version",
        "value": "0"
      }
    ],
    "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
    "mime_type": "text/markdown",
    "library_artifact_type": "report",
    "file_size_bytes": 4539,
    "external_connectors_accessed": false
  },
  "isError": false
}
```


## deliverables/library-master-layout-first-frame.json

```json
{
  "content": [
    {
      "type": "text",
      "text": "Action completed."
    }
  ],
  "structuredContent": {
    "operation": "create_library_file",
    "status": "succeeded",
    "path": "/0002-20261012T064346247Z.png",
    "file_id": "file_00000000d0048207a31150d3fc713813",
    "library_file_id": "libfile_f8cfaf966d988191b47d922270f90a79",
    "file_name": "0002-20261012T064346247Z.png",
    "current_version_number": 0,
    "restored_from_version_number": null,
    "xattrs": [
      {
        "name": "user.library-file-version",
        "value": "0"
      }
    ],
    "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
    "mime_type": "image/png",
    "library_artifact_type": "image",
    "file_size_bytes": 1032235,
    "external_connectors_accessed": false
  },
  "isError": false
}
```


## deliverables/library-native-images-20261012.json

```json
{
  "results": [
    {
      "operation": "create_library_file",
      "status": "succeeded",
      "path": "/20261012-lab-window-r0.png",
      "file_id": "file_000000004a6c821181709d3c167e7fa3",
      "library_file_id": "libfile_82e9f28d044081918b3035560115c100",
      "file_name": "20261012-lab-window-r0.png",
      "current_version_number": 0,
      "restored_from_version_number": null,
      "xattrs": [
        {
          "name": "user.library-file-version",
          "value": "0"
        }
      ],
      "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
      "mime_type": "image/png",
      "library_artifact_type": "image",
      "file_size_bytes": 441687
    },
    {
      "operation": "create_library_file",
      "status": "succeeded",
      "path": "/0072-20261012T043726467Z.png",
      "file_id": "file_00000000a1d48211aa74ec82644a4b35",
      "library_file_id": "libfile_7f835f5979fc81918c2fd2f46f3bda66",
      "file_name": "0072-20261012T043726467Z.png",
      "current_version_number": 0,
      "restored_from_version_number": null,
      "xattrs": [
        {
          "name": "user.library-file-version",
          "value": "0"
        }
      ],
      "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
      "mime_type": "image/png",
      "library_artifact_type": "image",
      "file_size_bytes": 634262
    },
    {
      "operation": "create_library_file",
      "status": "succeeded",
      "path": "/0052-20261012T043702975Z.png",
      "file_id": "file_00000000e1c08207ae4e135f8e6d46d4",
      "library_file_id": "libfile_c3026fc13f6c8191a53ce30c94736ce6",
      "file_name": "0052-20261012T043702975Z.png",
      "current_version_number": 0,
      "restored_from_version_number": null,
      "xattrs": [
        {
          "name": "user.library-file-version",
          "value": "0"
        }
      ],
      "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
      "mime_type": "image/png",
      "library_artifact_type": "image",
      "file_size_bytes": 157117
    },
    {
      "operation": "create_library_file",
      "status": "succeeded",
      "path": "/0013-20261012T043435139Z.png",
      "file_id": "file_000000002fa08209a040b64d2762c6b6",
      "library_file_id": "libfile_1b4bf42b4d948191bd0f64098f355a39",
      "file_name": "0013-20261012T043435139Z.png",
      "current_version_number": 0,
      "restored_from_version_number": null,
      "xattrs": [
        {
          "name": "user.library-file-version",
          "value": "0"
        }
      ],
      "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
      "mime_type": "image/png",
      "library_artifact_type": "image",
      "file_size_bytes": 79929
    }
  ],
  "warnings": [],
  "external_connectors_accessed": false
}
```


## deliverables/library-native-images-metadata.json

```json
[
  {
    "local_path": "D:\\taptap\\To-the-Human-World-3D-Lab\\docs\\evidence\\3d-lab-r3\\native\\20261012-lab-window-r0.png",
    "library_file_id": "libfile_82e9f28d044081918b3035560115c100",
    "version": 0,
    "upload_status": "succeeded",
    "xattr_exit": 1,
    "xattr_error": "Traceback (most recent call last):\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 303, in <module>\n    raise SystemExit(main(sys.argv[1:]))\n                     ~~~~^^^^^^^^^^^^^^\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 288, in main\n    materializer.apply_xattrs(\n    ~~~~~~~~~~~~~~~~~~~~~~~~~^\n        include_library_file_id_xattr(\n        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n    ...<3 lines>...\n        args.path,\n        ^^^^^^^^^^\n    )\n    ^\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 246, in apply_xattrs\n    xattr.apply(path)\n    ~~~~~~~~~~~^^^^^^\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 64, in apply\n    os.setxattr(path, self.name, encoded_value)\n    ^^^^^^^^^^^\nAttributeError: module 'os' has no attribute 'setxattr'\n"
  },
  {
    "local_path": "D:\\taptap\\To-the-Human-World-3D-Lab\\docs\\evidence\\3d-lab-r3\\native\\native-qa-local-r1\\0072-20261012T043726467Z.png",
    "library_file_id": "libfile_7f835f5979fc81918c2fd2f46f3bda66",
    "version": 0,
    "upload_status": "succeeded",
    "xattr_exit": 1,
    "xattr_error": "Traceback (most recent call last):\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 303, in <module>\n    raise SystemExit(main(sys.argv[1:]))\n                     ~~~~^^^^^^^^^^^^^^\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 288, in main\n    materializer.apply_xattrs(\n    ~~~~~~~~~~~~~~~~~~~~~~~~~^\n        include_library_file_id_xattr(\n        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n    ...<3 lines>...\n        args.path,\n        ^^^^^^^^^^\n    )\n    ^\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 246, in apply_xattrs\n    xattr.apply(path)\n    ~~~~~~~~~~~^^^^^^\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 64, in apply\n    os.setxattr(path, self.name, encoded_value)\n    ^^^^^^^^^^^\nAttributeError: module 'os' has no attribute 'setxattr'\n"
  },
  {
    "local_path": "D:\\taptap\\To-the-Human-World-3D-Lab\\docs\\evidence\\3d-lab-r3\\native\\native-qa-local-r1\\0052-20261012T043702975Z.png",
    "library_file_id": "libfile_c3026fc13f6c8191a53ce30c94736ce6",
    "version": 0,
    "upload_status": "succeeded",
    "xattr_exit": 1,
    "xattr_error": "Traceback (most recent call last):\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 303, in <module>\n    raise SystemExit(main(sys.argv[1:]))\n                     ~~~~^^^^^^^^^^^^^^\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 288, in main\n    materializer.apply_xattrs(\n    ~~~~~~~~~~~~~~~~~~~~~~~~~^\n        include_library_file_id_xattr(\n        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n    ...<3 lines>...\n        args.path,\n        ^^^^^^^^^^\n    )\n    ^\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 246, in apply_xattrs\n    xattr.apply(path)\n    ~~~~~~~~~~~^^^^^^\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 64, in apply\n    os.setxattr(path, self.name, encoded_value)\n    ^^^^^^^^^^^\nAttributeError: module 'os' has no attribute 'setxattr'\n"
  },
  {
    "local_path": "D:\\taptap\\To-the-Human-World-3D-Lab\\docs\\evidence\\3d-lab-r3\\native\\native-qa-local-r0\\0013-20261012T043435139Z.png",
    "library_file_id": "libfile_1b4bf42b4d948191bd0f64098f355a39",
    "version": 0,
    "upload_status": "succeeded",
    "xattr_exit": 1,
    "xattr_error": "Traceback (most recent call last):\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 303, in <module>\n    raise SystemExit(main(sys.argv[1:]))\n                     ~~~~^^^^^^^^^^^^^^\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 288, in main\n    materializer.apply_xattrs(\n    ~~~~~~~~~~~~~~~~~~~~~~~~~^\n        include_library_file_id_xattr(\n        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n    ...<3 lines>...\n        args.path,\n        ^^^^^^^^^^\n    )\n    ^\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 246, in apply_xattrs\n    xattr.apply(path)\n    ~~~~~~~~~~~^^^^^^\n  File \"D:\\taptap\\To-the-Human-World-3D-Lab\\tools\\library-writeback-20261012\\library_file_transfer.py\", line 64, in apply\n    os.setxattr(path, self.name, encoded_value)\n    ^^^^^^^^^^^\nAttributeError: module 'os' has no attribute 'setxattr'\n"
  }
]
```


## deliverables/library-preview-exit-diagnosis.json

```json
{
  "content": [
    {
      "type": "text",
      "text": "Action completed."
    }
  ],
  "structuredContent": {
    "operation": "create_library_file",
    "status": "succeeded",
    "path": "/REPORT(1).md",
    "file_id": "file_00000000ab3c8211a4cdd8270b8a91fc",
    "library_file_id": "libfile_779f178243508191b88109433df5920b",
    "file_name": "REPORT(1).md",
    "current_version_number": 0,
    "restored_from_version_number": null,
    "xattrs": [
      {
        "name": "user.library-file-version",
        "value": "0"
      }
    ],
    "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
    "mime_type": "text/markdown",
    "library_artifact_type": "report",
    "file_size_bytes": 3064,
    "external_connectors_accessed": false
  },
  "isError": false
}
```


## deliverables/library-replace-20261012-report.json

```json
{
  "local_path": "D:\\taptap\\To-the-Human-World-3D-Lab\\REPORT.md",
  "raw": {
    "content": [
      {
        "type": "text",
        "text": "Action completed."
      }
    ],
    "structuredContent": {
      "operation": "replace_library_file",
      "status": "succeeded",
      "path": "/REPORT.md",
      "file_id": "file_00000000b9588207b493f033981fe2da",
      "library_file_id": "libfile_2b7899edaabc819199c5b25a46bd693c",
      "file_name": "REPORT.md",
      "current_version_number": 1,
      "restored_from_version_number": null,
      "xattrs": [
        {
          "name": "user.library-file-version",
          "value": "1"
        }
      ],
      "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
      "mime_type": "text/markdown",
      "library_artifact_type": "other",
      "file_size_bytes": 10366,
      "external_connectors_accessed": false
    },
    "isError": false
  },
  "metadata": {
    "operation": "replace_library_file",
    "status": "succeeded",
    "path": "/REPORT.md",
    "file_id": "file_00000000b9588207b493f033981fe2da",
    "library_file_id": "libfile_2b7899edaabc819199c5b25a46bd693c",
    "file_name": "REPORT.md",
    "current_version_number": 1,
    "restored_from_version_number": null,
    "xattrs": [
      {
        "name": "user.library-file-version",
        "value": "1"
      }
    ],
    "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
    "mime_type": "text/markdown",
    "library_artifact_type": "other",
    "file_size_bytes": 10366,
    "external_connectors_accessed": false
  }
}
```


## deliverables/library-replace-20261012-review.json

```json
{
  "local_path": "D:\\taptap\\To-the-Human-World-3D-Lab\\deliverables\\D3-LAB-20261012-r3-v01-review.zip",
  "raw": {
    "content": [
      {
        "type": "text",
        "text": "Action completed."
      }
    ],
    "structuredContent": {
      "operation": "replace_library_file",
      "status": "succeeded",
      "path": "/D3-LAB-20261012-r3-v01-review.zip",
      "file_id": "file_00000000374c821196e5fc12e655fbf1",
      "library_file_id": "libfile_a96a3b502d5c8191a8fab49a5d70d685",
      "file_name": "D3-LAB-20261012-r3-v01-review.zip",
      "current_version_number": 1,
      "restored_from_version_number": null,
      "xattrs": [
        {
          "name": "user.library-file-version",
          "value": "1"
        }
      ],
      "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
      "mime_type": "application/zip",
      "library_artifact_type": "other",
      "file_size_bytes": 1280957,
      "external_connectors_accessed": false
    },
    "isError": false
  },
  "metadata": {
    "operation": "replace_library_file",
    "status": "succeeded",
    "path": "/D3-LAB-20261012-r3-v01-review.zip",
    "file_id": "file_00000000374c821196e5fc12e655fbf1",
    "library_file_id": "libfile_a96a3b502d5c8191a8fab49a5d70d685",
    "file_name": "D3-LAB-20261012-r3-v01-review.zip",
    "current_version_number": 1,
    "restored_from_version_number": null,
    "xattrs": [
      {
        "name": "user.library-file-version",
        "value": "1"
      }
    ],
    "directory_id": "libdir_c5d4f2edd6408191a7845dbbdc03151a",
    "mime_type": "application/zip",
    "library_artifact_type": "other",
    "file_size_bytes": 1280957,
    "external_connectors_accessed": false
  }
}
```


## deliverables/receipt.json

```json
{
  "path": "D:\\taptap\\To-the-Human-World-3D-Lab\\deliverables\\D3-LAB-20261012-r3-v01-review.zip",
  "size": 26704859,
  "sha256": "e594d5224f6e54e73f3c717d4a7ec07b9480f50d2909a33af2110c7cab42785e",
  "files": 610,
  "report_path": "D:\\taptap\\To-the-Human-World-3D-Lab\\REPORT.md",
  "report_size": 9434
}
```
