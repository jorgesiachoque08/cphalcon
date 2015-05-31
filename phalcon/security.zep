
/*
 +------------------------------------------------------------------------+
 | Phalcon Framework                                                      |
 +------------------------------------------------------------------------+
 | Copyright (c) 2011-2015 Phalcon Team (http://www.phalconphp.com)       |
 +------------------------------------------------------------------------+
 | This source file is subject to the New BSD License that is bundled     |
 | with this package in the file docs/LICENSE.txt.                        |
 |                                                                        |
 | If you did not receive a copy of the license and are unable to         |
 | obtain it through the world-wide-web, please send an email             |
 | to license@phalconphp.com so we can send you a copy immediately.       |
 +------------------------------------------------------------------------+
 | Authors: Andres Gutierrez <andres@phalconphp.com>                      |
 |          Eduar Carvajal <eduar@phalconphp.com>                         |
 +------------------------------------------------------------------------+
 */

namespace Phalcon;

use Phalcon\DiInterface;
use Phalcon\Security\Exception;
use Phalcon\Di\InjectionAwareInterface;
use Phalcon\Session\AdapterInterface as SessionInterface;

/**
 * Phalcon\Security
 *
 * This component provides a set of functions to improve the security in Phalcon applications
 *
 *<code>
 *	$login = $this->request->getPost('login');
 *	$password = $this->request->getPost('password');
 *
 *	$user = Users::findFirstByLogin($login);
 *	if ($user) {
 *		if ($this->security->checkHash($password, $user->password)) {
 *			//The password is valid
 *		}
 *	}
 *</code>
 */
class Security implements InjectionAwareInterface
{

	protected _dependencyInjector;

	protected _workFactor = 8 { set, get };

	protected _numberBytes = 16;

	protected _tokenKeySessionID = "$PHALCON/CSRF/KEY$";

	protected _tokenValueSessionID = "$PHALCON/CSRF$";

	protected _csrf;

	protected _defaultHash;

	const CRYPT_DEFAULT	   =	0;

	const CRYPT_STD_DES	   =	1;

	const CRYPT_EXT_DES	   =	2;

	const CRYPT_MD5		   =	3;

	const CRYPT_BLOWFISH       =	4;

	const CRYPT_BLOWFISH_X     =	5;

	const CRYPT_BLOWFISH_Y     =	6;

	const CRYPT_SHA256	   =	7;

	const CRYPT_SHA512	   =	8;

	/**
	 * Sets the dependency injector
	 */
	public function setDI(<DiInterface> dependencyInjector) -> void
	{
		let this->_dependencyInjector = dependencyInjector;
	}

	/**
	 * Returns the internal dependency injector
	 */
	public function getDI() -> <DiInterface>
	{
		return this->_dependencyInjector;
	}

	/**
	 * Sets a number of bytes to be generated by the openssl pseudo random generator
	 */
	public function setRandomBytes(long! randomBytes) -> void
	{
		let this->_numberBytes = randomBytes;
	}

	/**
	 * Returns a number of bytes to be generated by the openssl pseudo random generator
	 */
	public function getRandomBytes() -> string
	{
		return this->_numberBytes;
	}

	/**
	 * Generate a >22-length pseudo random string to be used as salt for passwords
	 */
	public function getSaltBytes(int numberBytes = 0) -> string
	{
		var safeBytes;

		if !function_exists("openssl_random_pseudo_bytes") {
			throw new Exception("Openssl extension must be loaded");
		}

		if !numberBytes {
			let numberBytes = (int) this->_numberBytes;
		}

		loop {

			/**
			 * Produce random bytes using openssl
			 * Filter alpha numeric characters
			 */
			let safeBytes = phalcon_filter_alphanum(base64_encode(openssl_random_pseudo_bytes(numberBytes)));

			if !safeBytes {
				continue;
			}

			if strlen(safeBytes) < numberBytes {
				continue;
			}

			break;
		}

		return safeBytes;
	}

	/**
	 * Creates a password hash using bcrypt with a pseudo random salt
	 */
	public function hash(string password, int workFactor = 0) -> string
	{
		int hash;
		string variant;
		var saltBytes;

		if !workFactor {
			let workFactor = (int) this->_workFactor;
		}

		let hash = (int) this->_defaultHash;

		switch hash {

			case self::CRYPT_BLOWFISH_X:
				let variant = "x";
				break;

			case self::CRYPT_BLOWFISH_Y:
				let variant = "y";
				break;

			case self::CRYPT_SHA256:
				let variant = "5";
				break;

			case self::CRYPT_SHA512:
				let variant = "6";
				break;

			case self::CRYPT_DEFAULT:
			default:
				let variant = "a";
				break;
		}

		switch hash {

			case self::CRYPT_STD_DES:

				/* Standard DES-based hash with a two character salt from the alphabet "./0-9A-Za-z". */

				let saltBytes = this->getSaltBytes(2);
				if typeof saltBytes != "string" {
					throw new Exception("Unable to get random bytes for the salt");
				}

				break;

			case self::CRYPT_DEFAULT:
			case self::CRYPT_BLOWFISH:
			case self::CRYPT_BLOWFISH_X:
			case self::CRYPT_BLOWFISH_Y:
			default:

				/*
				 * Blowfish hashing with a salt as follows: "$2a$", "$2x$" or "$2y$",
				 * a two digit cost parameter, "$", and 22 characters from the alphabet
				 * "./0-9A-Za-z". Using characters outside of this range in the salt
				 * will cause crypt() to return a zero-length string. The two digit cost
				 * parameter is the base-2 logarithm of the iteration count for the
				 * underlying Blowfish-based hashing algorithm and must be in
				 * range 04-31, values outside this range will cause crypt() to fail.
				 */

				let saltBytes = this->getSaltBytes(22);
				if typeof saltBytes != "string" {
					throw new Exception("Unable to get random bytes for the salt");
				}

				if workFactor < 4 {
					let workFactor = 4;
				} else {
					if workFactor > 31 {
						let workFactor = 31;
					}
				}

				return crypt(password, "$2" . variant . "$" . sprintf("%02s", workFactor) . "$" . saltBytes);
		}

		return "";
	}

	/**
	 * Checks a plain text password and its hash version to check if the password matches
	 */
	public function checkHash(string password, string passwordHash, int maxPassLength = 0) -> boolean
	{
		char ch;
		string cryptedHash;
		int i, sum, cryptedLength, passwordLength;

		if maxPassLength {
			if maxPassLength > 0 && strlen(password) > maxPassLength {
				return false;
			}
		}

		let cryptedHash = (string) crypt(password, passwordHash);

		let cryptedLength = strlen(cryptedHash),
			passwordLength = strlen(passwordHash);

		let cryptedHash .= passwordHash;

		let sum = cryptedLength - passwordLength;
		for i, ch in passwordHash {
			let sum = sum | (cryptedHash[i] ^ ch);
		}

		return 0 === sum;
	}

	/**
	 * Checks if a password hash is a valid bcrypt's hash
	 */
	public function isLegacyHash(string passwordHash) -> boolean
	{
		return starts_with(passwordHash, "$2a$");
	}

	/**
	 * Generates a pseudo random token key to be used as input's name in a CSRF check
	 */
	public function getTokenKey(int numberBytes = null) -> string
	{
		var safeBytes, dependencyInjector, session;

		if !numberBytes {
			let numberBytes = 12;
		}

		if !function_exists("openssl_random_pseudo_bytes") {
			throw new Exception("Openssl extension must be loaded");
		}

		let dependencyInjector = <DiInterface> this->_dependencyInjector;
		if typeof dependencyInjector != "object" {
			throw new Exception("A dependency injection container is required to access the 'session' service");
		}

		let safeBytes = phalcon_filter_alphanum(base64_encode(openssl_random_pseudo_bytes(numberBytes)));
		let session = <SessionInterface> dependencyInjector->getShared("session");
		session->set(this->_tokenKeySessionID, safeBytes);

		return safeBytes;
	}

	/**
	 * Generates a pseudo random token value to be used as input's value in a CSRF check
	 */
	public function getToken(int numberBytes = null) -> string
	{
		var token, dependencyInjector, session;

		if !numberBytes {
			let numberBytes = 12;
		}

		if !function_exists("openssl_random_pseudo_bytes") {
			throw new Exception("Openssl extension must be loaded");
		}

		let token = openssl_random_pseudo_bytes(numberBytes);
		let token = base64_encode(token);
		let token = phalcon_filter_alphanum(token);

		let dependencyInjector = <DiInterface> this->_dependencyInjector;

		if typeof dependencyInjector != "object" {
			throw new Exception("A dependency injection container is required to access the 'session' service");
		}

		let session = <SessionInterface> dependencyInjector->getShared("session");
		session->set(this->_tokenValueSessionID, token);

		return token;
	}

	/**
	 * Check if the CSRF token sent in the request is the same that the current in session
	 */
	public function checkToken(var tokenKey = null, var tokenValue = null, boolean destroyIfValid = true) -> boolean
	{
		var dependencyInjector, session, request, token, returnValue;

		let dependencyInjector = <DiInterface> this->_dependencyInjector;

		if typeof dependencyInjector != "object" {
			throw new Exception("A dependency injection container is required to access the 'session' service");
		}

		let session = <SessionInterface> dependencyInjector->getShared("session");

		if !tokenKey {
			let tokenKey = session->get(this->_tokenKeySessionID);
		}

		/**
		 * If tokenKey does not exist in session return false
		 */
		if !tokenKey {
			return false;
		}

		if !tokenValue {
			let request = dependencyInjector->getShared("request");

			/**
			 * We always check if the value is correct in post
			 */
			let token = request->getPost(tokenKey);
		} else {
			let token = tokenValue;
		}

		/**
		 * The value is the same?
		 */
		let returnValue = (token == session->get(this->_tokenValueSessionID));

		/**
		 * Remove the key and value of the CSRF token in session
		 */
		if returnValue && destroyIfValid {
			session->remove(this->_tokenKeySessionID);
			session->remove(this->_tokenValueSessionID);
		}

		return returnValue;
	}

	/**
	 * Returns the value of the CSRF token in session
	 */
	public function getSessionToken() -> string
	{
		var dependencyInjector, session;

		let dependencyInjector = <DiInterface> this->_dependencyInjector;

		if typeof dependencyInjector != "object" {
			throw new Exception("A dependency injection container is required to access the 'session' service");
		}

		let session = <SessionInterface> dependencyInjector->getShared("session");
		return session->get(this->_tokenValueSessionID);
	}

	/**
	 * Removes the value of the CSRF token and key from session
	 */
	public function destroyToken()
	{
		var dependencyInjector, session;

		let dependencyInjector = <DiInterface> this->_dependencyInjector;

		if typeof dependencyInjector != "object" {
			throw new Exception("A dependency injection container is required to access the 'session' service");
		}

		let session = <SessionInterface> dependencyInjector->getShared("session");

		session->remove(this->_tokenKeySessionID);
		session->remove(this->_tokenValueSessionID);
	}

	/**
	 * Computes a HMAC
	 *
	 * @param string data
	 * @param string key
	 * @param string algo
	 * @param boolean raw
	 */
	public function computeHmac(data, key, algo, boolean raw = false)
	{
		var hmac;

		let hmac = hash_hmac(algo, data, key, raw);
		if !hmac {
			throw new Exception("Unknown hashing algorithm: %s" . algo);
		}

		return hmac;
	}

	/**
 	 * Sets the default hash
 	 */
	public function setDefaultHash(var defaultHash)
	{
		let this->_defaultHash = defaultHash;
	}

	/**
 	 * Sets the default hash
 	 */
	public function getDefaultHash()
	{
		return this->_defaultHash;
	}
}