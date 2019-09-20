<?php
declare(strict_types=1);

/**
 * This file is part of the Phalcon Framework.
 *
 * (c) Phalcon Team <team@phalconphp.com>
 *
 * For the full copyright and license information, please view the LICENSE.txt
 * file that was distributed with this source code.
 */

namespace Phalcon\Test\Unit\Assets\Asset\Js;

use Codeception\Example;
use Phalcon\Assets\Asset\Js;
use UnitTester;

class SetPathCest
{
    /**
     * Tests Phalcon\Assets\Asset\Js :: setPath()
     *
     * @author       Phalcon Team <team@phalconphp.com>
     * @since        2018-11-13
     *
     * @dataProvider provider
     */
    public function assetsAssetJsSetPath(UnitTester $I, Example $example)
    {
        $I->wantToTest('Assets\Asset\Js - setPath()');

        $asset = new Js(
            $example['path'],
            $example['local']
        );

        $path = '/new/path';

        $asset->setPath($path);

        $I->assertEquals(
            $path,
            $asset->getPath()
        );
    }

    protected function provider(): array
    {
        return [
            [
                'path'  => 'js/jquery.js',
                'local' => true,
            ],
            [
                'path'  => 'https://phalcon.ld/js/jquery.js',
                'local' => false,
            ],
        ];
    }
}