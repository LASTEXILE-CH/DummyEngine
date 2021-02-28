#include "test_common.h"

#include <vector>

#include "../Utils.h"

void test_utils() {
    std::unique_ptr<uint8_t[]> data_in(new uint8_t[256 * 256 * 256 * 3]);

    { // fill initial array with test data
        uint8_t *_data_in = data_in.get();
        for (int r = 0; r < 256; r++) {
            for (int g = 0; g < 256; g++) {
                for (int b = 0; b < 256; b++) {
                    (*_data_in++) = uint8_t(r);
                    (*_data_in++) = uint8_t(g);
                    (*_data_in++) = uint8_t(b);
                }
            }
        }
    }

    { // Convert to YCoCg and back to RGB to check reversability
        auto data_CoCg_Y = Ren::ConvertRGB_to_CoCgxY_rev(data_in.get(), 256 * 256, 256);
        auto data_RGB = Ren::ConvertCoCgxY_to_RGB_rev(data_CoCg_Y.get(), 256 * 256, 256);

        const uint8_t *_data_in = data_in.get();
        const uint8_t *_data_RGB = data_RGB.get();
        for (int r = 0; r < 256; r++) {
            for (int g = 0; g < 256; g++) {
                for (int b = 0; b < 256; b++) {
                    require((*_data_RGB++) == (*_data_in++));
                    require((*_data_RGB++) == (*_data_in++));
                    require((*_data_RGB++) == (*_data_in++));
                }
            }
        }
    }

    { // Convert to YCoCg and back to RGB to check reversability
        auto data_CoCg_Y = Ren::ConvertRGB_to_CoCgxY(data_in.get(), 256 * 256, 256);
        auto data_RGB = Ren::ConvertCoCgxY_to_RGB(data_CoCg_Y.get(), 256 * 256, 256);

        const uint8_t *_data_in = data_in.get();
        const uint8_t *_data_RGB = data_RGB.get();
        for (int r = 0; r < 256; r++) {
            for (int g = 0; g < 256; g++) {
                for (int b = 0; b < 256; b++) {
                    require((*_data_RGB++) == (*_data_in++));
                    require((*_data_RGB++) == (*_data_in++));
                    require((*_data_RGB++) == (*_data_in++));
                }
            }
        }
    }
}